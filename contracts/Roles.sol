// SPDX-License-Identifier: GPL-2.0-only
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";

enum ContractRoles {
    WITHDRAWER,
    MARGIN_CALLER,
    BORROWER,
    MARGIN_TRADER,
    FEE_SOURCE,
    LIQUIDATOR,
    AUTHORIZED_FUND_TRADER,
    INCENTIVE_REPORTER
}

enum Characters {
    FUND,
    LENDING,
    ROUTER,
    MARGIN_TRADING,
    FEE_CONTROLLER,
    PRICE_CONTROLLER
}

contract Roles is Ownable {
    mapping(address => mapping(ContractRoles => bool)) public roles;
    mapping(Characters => address) public mainCharacters;

    function giveRole(ContractRoles role, address actor) external onlyOwner {
        roles[actor][role] = true;
    }

    function removeRole(ContractRoles role, address actor) external onlyOwner {
        roles[actor][role] = false;
    }

    function setMainCharacter(Characters role, address actor)
        external
        onlyOwner
    {
        mainCharacters[role] = actor;
    }

    function getRole(address contr, ContractRoles role)
        external
        view
        returns (bool)
    {
        return roles[contr][role];
    }
}
