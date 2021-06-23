// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "./IsolatedMarginLiquidation.sol";

contract IsolatedMarginTrading is IsolatedMarginLiquidation {
    constructor(
        address[] memory _liquidationTokens,
        bytes32 _amms,
        address _roles
    ) RoleAware(_roles) {
        liquidationTokens = _liquidationTokens;
        amms = _amms;

        borrowToken = _liquidationTokens[_liquidationTokens.length - 1];
        holdingToken = _liquidationTokens[0];
    }

    /// @dev last time this account deposited
    /// relevant for withdrawal window
    function getLastDepositBlock(address trader)
        external
        view
        returns (uint256)
    {
        return marginAccounts[trader].lastDepositBlock;
    }

    /// @dev setter for cooling off period for withdrawing funds after deposit
    function setCoolingOffPeriod(uint256 blocks) external onlyOwnerExec {
        coolingOffPeriod = blocks;
    }

    /// @dev admin function to set leverage
    function setLeveragePercent(uint256 _leveragePercent)
        external
        onlyOwnerExec
    {
        leveragePercent = _leveragePercent;
    }

    /// @dev admin function to set liquidation threshold
    function setLiquidationThresholdPercent(uint256 threshold)
        external
        onlyOwnerExec
    {
        liquidationThresholdPercent = threshold;
    }

    /// @dev gets called by router to affirm trader taking position
    function registerPosition(
        address trader,
        uint256 borrowed,
        uint256 holdingsAdded,
        bool deposited
    ) external {
        require(
            isMarginTrader(msg.sender),
            "Calling contract not authorized to deposit"
        );

        IsolatedMarginAccount storage account = marginAccounts[trader];

        account.holding += holdingsAdded;
        borrow(account, borrowed);

        if (deposited) {
            account.lastDepositBlock = block.number;
        }
    }

    /// @dev gets called by router to affirm unwinding of position
    function registerUnwind(
        address trader,
        uint256 extinguished,
        uint256 holdingsSold
    ) external {
        require(
            isMarginTrader(msg.sender),
            "Calling contract not authorized to withdraw"
        );

        IsolatedMarginAccount storage account = marginAccounts[trader];
        require(
            block.number > account.lastDepositBlock + coolingOffPeriod,
            "To prevent attacks you must wait until your cooling off period is over to withdraw"
        );

        account.holding -= holdingsSold;
        extinguishDebt(account, extinguished);
        require(positiveBalance(account), "Insufficient remaining balance");
    }

    /// @dev gets called by router to close account
    function registerCloseAccount(address trader)
        external
        returns (uint256 holdingAmount)
    {
        require(
            isMarginTrader(msg.sender),
            "Calling contract not authorized to deposit"
        );

        IsolatedMarginAccount storage account = marginAccounts[trader];
        require(
            block.number > account.lastDepositBlock + coolingOffPeriod,
            "To prevent attacks you must wait until your cooling off period is over to withdraw"
        );

        require(account.borrowed == 0, "Can't close account that's borrowing");

        holdingAmount = account.holding;

        delete marginAccounts[trader];
    }
}
