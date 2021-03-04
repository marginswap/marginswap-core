// SPDX-License-Identifier: GPL-2.0-only
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";

contract Roles is Ownable {
    mapping(address => mapping(uint16 => bool)) public roles;
    mapping(uint16 => address) public mainCharacters;

    function giveRole(uint16 role, address actor) external onlyOwner {
        roles[actor][role] = true;
    }

    function removeRole(uint16 role, address actor) external onlyOwner {
        roles[actor][role] = false;
    }

    function setMainCharacter(uint16 role, address actor) external onlyOwner {
        mainCharacters[role] = actor;
    }

    function getRole(uint16 role, address contr) external view returns (bool) {
        return roles[contr][role];
    }
}
