// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

interface IDelegateOwner {
    function relinquishOwnership(address property, address newOwner) external;
}
