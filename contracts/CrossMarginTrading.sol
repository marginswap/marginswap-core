// SPDX-License-Identifier: GPL-2.0-only
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "./Fund.sol";
import "./Lending.sol";
import "./RoleAware.sol";
import "./MarginRouter.sol";
import "./CrossMarginLiquidation.sol";

// Goal: all external functions only accessible to margintrader role
// except for view functions of course

contract CrossMarginTrading is CrossMarginLiquidation, IMarginTrading {
    constructor(address _peg, address _roles)
        RoleAware(_roles)
        PriceAware(_peg)
    {
        liquidationThresholdPercent = 110;
        coolingOffPeriod = 20;
    }

    /// @dev admin function to set the token cap
    function setTokenCap(address token, uint256 cap) external {
        require(
            isTokenActivator(msg.sender),
            "Caller not authorized to set token cap"
        );
        tokenCaps[token] = cap;
    }

    /// @dev setter for cooling off period for withdrawing funds after deposit
    function setCoolingOffPeriod(uint256 blocks) external onlyOwner {
        coolingOffPeriod = blocks;
    }

    /// @dev admin function to set leverage
    function setLeverage(uint256 _leverage) external onlyOwner {
        leverage = _leverage;
    }

    /// @dev admin function to set liquidation threshold
    function setLiquidationThresholdPercent(uint256 threshold)
        external
        onlyOwner
    {
        liquidationThresholdPercent = threshold;
    }

    /// @dev gets called by router to affirm a deposit to an account
    function registerDeposit(
        address trader,
        address token,
        uint256 depositAmount
    ) external override returns (uint256 extinguishableDebt) {
        require(
            isMarginTrader(msg.sender),
            "Calling contract not authorized to deposit"
        );

        CrossMarginAccount storage account = marginAccounts[trader];
        if (account.borrowed[token] > 0) {
            extinguishableDebt = min(depositAmount, account.borrowed[token]);
            extinguishDebt(account, token, extinguishableDebt);
            totalShort[token] -= extinguishableDebt;
        }
        // no overflow because depositAmount >= extinguishableDebt
        uint256 addedHolding = depositAmount - extinguishableDebt;
        addHolding(account, token, addedHolding);

        totalLong[token] += addedHolding;
        require(
            tokenCaps[token] >= totalLong[token],
            "Exceeding global exposure cap to token -- try again later"
        );

        account.lastDepositBlock = block.number;
    }

    /// @dev gets called by router to affirm isolated borrowing event
    function registerBorrow(
        address trader,
        address borrowToken,
        uint256 borrowAmount
    ) external override {
        require(
            isMarginTrader(msg.sender),
            "Calling contract not authorized to deposit"
        );
        totalShort[borrowToken] += borrowAmount;
        totalLong[borrowToken] += borrowAmount;
        require(
            tokenCaps[borrowToken] >= totalShort[borrowToken] &&
                tokenCaps[borrowToken] >= totalLong[borrowToken],
            "Exceeding global exposure cap to token -- try again later"
        );

        CrossMarginAccount storage account = marginAccounts[trader];
        borrow(account, borrowToken, borrowAmount);
    }

    /// @dev gets called by router to affirm withdrawal of tokens from account
    function registerWithdrawal(
        address trader,
        address withdrawToken,
        uint256 withdrawAmount
    ) external override {
        require(
            isMarginTrader(msg.sender),
            "Calling contract not authorized to deposit"
        );
        CrossMarginAccount storage account = marginAccounts[trader];
        require(
            block.number > account.lastDepositBlock + coolingOffPeriod,
            "To prevent attacks you must wait until your cooling off period is over to withdraw"
        );

        require(
            totalLong[withdrawToken] >= withdrawAmount,
            "Not enough long to withdraw"
        );

        totalLong[withdrawToken] -= withdrawAmount;
        // throws on underflow
        account.holdings[withdrawToken] =
            account.holdings[withdrawToken] -
            withdrawAmount;
        require(
            positiveBalance(account),
            "Account balance is too low to withdraw"
        );
    }

    /// @dev gets callled by router to register a trade and borrow and extinguis as necessary
    function registerTradeAndBorrow(
        address trader,
        address tokenFrom,
        address tokenTo,
        uint256 inAmount,
        uint256 outAmount
    )
        external
        override
        returns (uint256 extinguishableDebt, uint256 borrowAmount)
    {
        require(
            isMarginTrader(msg.sender),
            "Calling contract is not an authorized margin trader agent"
        );

        CrossMarginAccount storage account = marginAccounts[trader];

        if (account.borrowed[tokenTo] > 0) {
            extinguishableDebt = min(outAmount, account.borrowed[tokenTo]);
            extinguishDebt(account, tokenTo, extinguishableDebt);
            totalShort[tokenTo] -= extinguishableDebt;
        }
        totalLong[tokenFrom] -= inAmount;
        totalLong[tokenTo] += outAmount - extinguishableDebt;
        require(
            tokenCaps[tokenTo] >= totalLong[tokenTo],
            "Exceeding global exposure cap to token -- try again later"
        );

        uint256 sellAmount = inAmount;
        if (inAmount > account.holdings[tokenFrom]) {
            sellAmount = account.holdings[tokenFrom];
            /// won't overflow
            borrowAmount = inAmount - sellAmount;

            totalShort[tokenFrom] += borrowAmount;
            require(
                tokenCaps[tokenFrom] >= totalShort[tokenFrom],
                "Exceeding global exposure cap to token -- try again later"
            );

            borrow(account, tokenFrom, borrowAmount);
        }
        adjustAmounts(account, tokenFrom, tokenTo, sellAmount, outAmount);
    }

    /// @dev can get called by router to register the dissolution of an account
    function registerLiquidation(address trader) external override {
        require(
            isMarginTrader(msg.sender),
            "Calling contract is not an authorized margin trader agent"
        );

        CrossMarginAccount storage account = marginAccounts[trader];
        for (uint24 i = 0; account.borrowTokens.length > i; i++) {
            address token = account.borrowTokens[i];
            Lending(lending()).payOff(token, account.borrowed[token]);
        }

        deleteAccount(account);
    }
}
