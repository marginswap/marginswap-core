// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

interface IExecutor {
    function rightfulOwner() external view returns (address);

    function execute() external;

    function requiredProperties() external view returns (address[] memory);

    function requiredRoles() external view returns (uint256[] memory);
}
