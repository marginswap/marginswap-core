// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "../DependencyController.sol";

abstract contract SelfDestructReturningExec is IExecutor {
    address public override rightfulOwner;
    uint256[] public _requiredRoles;
    uint256[] public propertyCharacters;
    address[] public extraProperties;

    constructor(address controller) {
        rightfulOwner = controller;
    }

    function requiredRoles() external view override returns (uint256[] memory) {
        return _requiredRoles;
    }

    function requiredProperties()
        external
        view
        override
        returns (address[] memory)
    {
        return _requiredProps();
    }

    function roles() internal view returns (Roles) {
        return DependencyController(rightfulOwner).roles();
    }

    function _requiredProps()
        internal
        view
        returns (address[] memory properties)
    {
        properties = new address[](
            extraProperties.length + propertyCharacters.length
        );

        for (uint24 char = 0; propertyCharacters.length > char; char++) {
            properties[char] = roles().mainCharacters(propertyCharacters[char]);
        }

        for (uint24 extra = 0; extraProperties.length > extra; extra++) {
            properties[extra + propertyCharacters.length] = extraProperties[
                extra
            ];
        }
    }

    function _execute() internal virtual;

    function execute() external override {
        require(
            msg.sender == rightfulOwner,
            "Only rightful owner is allowed to call execute()"
        );

        _execute();

        address[] memory properties = _requiredProps();
        for (uint24 i = 0; properties.length > i; i++) {
            Ownable(properties[i]).transferOwnership(rightfulOwner);
        }

        selfdestruct(payable(tx.origin));
    }
}
