// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "../Executor.sol";

import "../DependencyController.sol";

abstract contract SpecialMigration is Executor {
    address oldContract;
    address[] accounts;
    address[] tokens;
    uint256[] amounts;

    constructor(
        address _oldContract,
        address[] memory _accounts,
        address[] memory _tokens,
        uint256[] memory _amounts,
        address _roles
    ) RoleAware(_roles) {
        oldContract = _oldContract;
        accounts = _accounts;
        tokens = _tokens;
        amounts = _amounts;
    }

    function requiredRoles()
        external
        pure
        override
        returns (uint256[] memory required)
    {
        required = new uint256[](2);

        required[0] = MARGIN_TRADER;
        required[1] = LENDER;
    }

    function execute() external override {
        _execute();

        delete accounts;
        delete tokens;
        delete amounts;

        if (oldContract != address(0)) {
            DependencyController(msg.sender).disableContract(oldContract);
        }
        selfdestruct(payable(tx.origin));
    }

    function _execute() internal virtual;
}
