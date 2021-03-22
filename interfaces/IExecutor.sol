// SPDX-License-Identifier: GPL-2.0-only
pragma solidity ^0.8.0;

interface IExecutor {
    function rightfulOwner() external returns (address);

    function execute() external;

    function requiredProperties() external view returns (address[] memory);

    function requiredRoles() external returns (uint16[] memory);
}
