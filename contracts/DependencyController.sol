// SPDX-License-Identifier: GPL-2.0-only
pragma solidity ^0.8.0;

import "./RoleAware.sol";
import "../interfaces/IExecutor.sol";
import "../interfaces/IDelegateOwner.sol";

contract DependencyController is RoleAware, Ownable, IDelegateOwner {
    constructor(address _roles) RoleAware(_roles) Ownable() {}

    address[] public managedContracts;
    mapping(uint16 => bool) public knownCharacters;
    mapping(uint16 => bool) public knownRoles;
    mapping(address => address) public delegateOwner;

    uint16[] public allCharacters;
    uint16[] public allRoles;

    function relinquishOwnership(address ownableContract, address newOwner)
        external
        override
        onlyOwner
    {
        Ownable(ownableContract).transferOwnership(newOwner);
    }

    function executeAsOwner(address executor, address[] memory properties)
        external
        onlyOwner
    {
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

        IExecutor(executor).execute(address(this));

        for (uint256 i = 0; properties.length > i; i++) {
            address property = properties[i];
            require(
                Ownable(property).owner() == address(this),
                "Executor did not return ownership"
            );
            if (delegateOwner[property] != address(0)) {
                Ownable(property).transferOwnership(delegateOwner[property]);
            }
        }
    }

    function manageContract(
        address contr,
        uint16[] memory charactersPlayed,
        uint16[] memory rolesPlayed,
        address[] memory ownsAsDelegate
    ) external onlyOwner {
        managedContracts.push(contr);

        // set up all characters this contract plays
        for (uint256 i = 0; charactersPlayed.length > i; i++) {
            uint16 character = charactersPlayed[i];
            _setMainCharacter(character, contr);
        }

        // all roles this contract plays
        for (uint256 i = 0; rolesPlayed.length > i; i++) {
            uint16 role = rolesPlayed[i];
            _giveRole(role, contr);
        }

        // update this contract with all characters we know about
        for (uint256 i = 0; allCharacters.length > i; i++) {
            RoleAware(contr).updateMainCharacterCache(allCharacters[i]);
        }

        // update this contract with all roles for all contracts we know about
        for (uint256 i = 0; allRoles.length > i; i++) {
            for (uint256 j = 0; managedContracts.length > i; i++) {
                RoleAware(contr).updateRoleCache(
                    allRoles[i],
                    managedContracts[j]
                );
            }
        }

        for (uint256 i = 0; ownsAsDelegate.length > i; i++) {
            Ownable(ownsAsDelegate[i]).transferOwnership(contr);
            delegateOwner[ownsAsDelegate[i]] = contr;
        }
    }

    function giveRole(uint16 role, address actor) external onlyOwner {
        _giveRole(role, actor);
    }

    function removeRole(uint16 role, address actor) external onlyOwner {
        roles.removeRole(role, actor);
        updateRoleCache(role, actor);
    }

    function setMainCharacter(uint16 role, address actor) external onlyOwner {
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
        for (uint256 i = 0; managedContracts.length > i; i++) {
            RoleAware(managedContracts[i]).updateMainCharacterCache(character);
        }
    }

    function updateRoleCache(uint16 role, address contr) public override {
        for (uint256 i = 0; managedContracts.length > i; i++) {
            RoleAware(managedContracts[i]).updateRoleCache(role, contr);
        }
    }
}
