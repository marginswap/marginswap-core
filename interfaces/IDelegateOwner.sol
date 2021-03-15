// SPDX-License-Identifier: GPL-2.0-only
pragma solidity ^0.8.0;

interface IDelegateOwner {
    function relinquishOwnership(address property, address newOwner) external;
}
