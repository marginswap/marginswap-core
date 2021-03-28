// SPDX-License-Identifier: GPL-2.0-only
pragma solidity ^0.8.0;

import "./RoleAware.sol";
import "../interfaces/IExecutor.sol";
import "../interfaces/IDelegateOwner.sol";

/// @dev Provides a single point of reference to verify ownership integrity
/// within our system as well as performing cache invalidation for
/// roles and inter-contract relationships
contract DependencyController is RoleAware, Ownable, IDelegateOwner {
    constructor(address _roles) RoleAware(_roles) Ownable() {}

    address[] public managedContracts;
    mapping(uint16 => bool) public knownCharacters;
    mapping(uint16 => bool) public knownRoles;
    mapping(address => address) public delegateOwner;
    mapping(address => bool) public disabler;
    address public currentExecutor = address(0);

    uint16[] public allCharacters;
    uint16[] public allRoles;

    modifier onlyOwnerOrExecOrDisabler() {
        require(
            owner() == _msgSender() ||
                disabler[_msgSender()] ||
                currentExecutor == _msgSender(),
            "Caller is not the owner or authorized disabler or executor"
        );
        _;
    }

    modifier onlyOwnerOrExec() {
        require(
            owner() == _msgSender() || currentExecutor == _msgSender(),
            "Caller is not the owner or executor"
        );
        _;
    }

    function verifyOwnership() external view returns (bool ownsAll) {
        ownsAll = ownsContractStrict(address(roles));
        uint256 len = managedContracts.length;
        for (uint256 i = 0; len > i; i++) {
            address contr = managedContracts[i];
            ownsAll = ownsAll && ownsContract(contr);
        }
    }

    function verifyOwnershipStrict() external view returns (bool ownsAll) {
        ownsAll = ownsContractStrict(address(roles));
        uint256 len = managedContracts.length;
        for (uint256 i = 0; len > i; i++) {
            address contr = managedContracts[i];
            ownsAll = ownsAll && ownsContractStrict(contr);
        }
    }

    function ownsContract(address contr) public view returns (bool) {
        address contrOwner = Ownable(contr).owner();
        return
            contrOwner == address(this) ||
            contrOwner == owner() ||
            (delegateOwner[contr] != address(0) &&
             contrOwner == delegateOwner[contr]);
    }

    function ownsContractStrict(address contr) public view returns (bool) {
        address contrOwner = Ownable(contr).owner();
        return
            contrOwner == address(this) ||
            (contrOwner == delegateOwner[contr] &&
                Ownable(delegateOwner[contr]).owner() == address(this));
    }

    function relinquishOwnership(address ownableContract, address newOwner)
        external
        override
        onlyOwnerOrExec
    {
        Ownable(ownableContract).transferOwnership(newOwner);
    }

    function setDisabler(address disablerAddress, bool authorized)
        external
        onlyOwnerOrExec
    {
        disabler[disablerAddress] = authorized;
    }

    function executeAsOwner(address executor) external onlyOwnerOrExec {
        address[] memory properties = IExecutor(executor).requiredProperties();
        for (uint256 i = 0; properties.length > i; i++) {
            address property = properties[i];
            if (delegateOwner[property] != address(0)) {
                IDelegateOwner(delegateOwner[property]).relinquishOwnership(
                    property,
                    executor
                );
            } else {
                Ownable(property).transferOwnership(executor);
            }
        }

        uint16[] memory requiredRoles = IExecutor(executor).requiredRoles();

        for (uint256 i = 0; requiredRoles.length > i; i++) {
            _giveRole(requiredRoles[i], executor);
        }

        currentExecutor = executor;
        IExecutor(executor).execute();
        currentExecutor = address(0);

        address rightfulOwner = IExecutor(executor).rightfulOwner();
        require(
            rightfulOwner == address(this) || rightfulOwner == owner(),
            "Executor doesn't have the right rightful owner"
        );

        uint256 len = properties.length;
        for (uint256 i = 0; len > i; i++) {
            address property = properties[i];
            require(
                Ownable(property).owner() == rightfulOwner,
                "Executor did not return ownership"
            );
            if (delegateOwner[property] != address(0)) {
                Ownable(property).transferOwnership(delegateOwner[property]);
            }
        }

        len = requiredRoles.length;
        for (uint256 i = 0; len > i; i++) {
            _removeRole(requiredRoles[i], executor);
        }
    }

    function manageContract(
        address contr,
        uint16[] memory charactersPlayed,
        uint16[] memory rolesPlayed,
        address[] memory ownsAsDelegate
    ) external onlyOwnerOrExec {
        managedContracts.push(contr);

        // set up all characters this contract plays
        uint256 len = charactersPlayed.length;
        for (uint256 i = 0; len > i; i++) {
            uint16 character = charactersPlayed[i];
            _setMainCharacter(character, contr);
        }

        // all roles this contract plays
        len = rolesPlayed.length;
        for (uint256 i = 0; len > i; i++) {
            uint16 role = rolesPlayed[i];
            _giveRole(role, contr);
        }

        // update this contract with all characters we know about
        len = allCharacters.length;
        for (uint256 i = 0; len > i; i++) {
            RoleAware(contr).updateMainCharacterCache(allCharacters[i]);
        }

        // update this contract with all roles for all contracts we know about
        len = allRoles. length;
        for (uint256 i = 0; len > i; i++) {
            for (uint256 j = 0; managedContracts.length > j; j++) {
                RoleAware(contr).updateRoleCache(
                    allRoles[i],
                    managedContracts[j]
                );
            }
        }

        len = ownsAsDelegate.length;
        for (uint256 i = 0; len > i; i++) {
            Ownable(ownsAsDelegate[i]).transferOwnership(contr);
            delegateOwner[ownsAsDelegate[i]] = contr;
        }
    }

    function disableContract(address contr) external onlyOwnerOrExecOrDisabler {
        _disableContract(contr);
    }

    function _disableContract(address contr) internal {
        uint256 len = allRoles.length;
        for (uint256 i = 0; len > i; i++) {
            if (roles.getRole(allRoles[i], contr)) {
                _removeRole(allRoles[i], contr);
            }
        }

        len = allCharacters.length;
        for (uint256 i = 0; len > i; i++) {
            if (roles.mainCharacters(allCharacters[i]) == contr) {
                _setMainCharacter(allCharacters[i], address(0));
            }
        }
    }

    function giveRole(uint16 role, address actor) external onlyOwnerOrExec {
        _giveRole(role, actor);
    }

    function removeRole(uint16 role, address actor)
        external
        onlyOwnerOrExecOrDisabler
    {
        _removeRole(role, actor);
    }

    function _removeRole(uint16 role, address actor) internal {
        roles.removeRole(role, actor);
        updateRoleCache(role, actor);
    }

    function setMainCharacter(uint16 role, address actor)
        external
        onlyOwnerOrExec
    {
        _setMainCharacter(role, actor);
    }

    function _giveRole(uint16 role, address actor) internal {
        if (!knownRoles[role]) {
            knownRoles[role] = true;
            allRoles.push(role);
        }
        roles.giveRole(role, actor);
        updateRoleCache(role, actor);
    }

    function _setMainCharacter(uint16 character, address actor) internal {
        if (!knownCharacters[character]) {
            knownCharacters[character] = true;
            allCharacters.push(character);
        }
        roles.setMainCharacter(character, actor);
        updateMainCharacterCache(character);
    }

    function updateMainCharacterCache(uint16 character) public override {
        uint256 len = managedContracts.length;
        for (uint256 i = 0; len > i; i++) {
            RoleAware(managedContracts[i]).updateMainCharacterCache(character);
        }
    }

    function updateRoleCache(uint16 role, address contr) public override {
        uint256 len = managedContracts.length;
        for (uint256 i = 0; len > i; i++) {
            RoleAware(managedContracts[i]).updateRoleCache(role, contr);
        }
    }

    function allManagedContracts() external view returns (address[] memory) {
        return managedContracts;
    }
}
