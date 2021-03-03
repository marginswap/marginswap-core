// SPDX-License-Identifier: GPL-2.0-only
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "./Fund.sol";
import "./Lending.sol";
import "./RoleAware.sol";
import "./MarginRouter.sol";
import "./Price.sol";

// Goal: all external functions only accessible to margintrader role
// except for view functions of course

struct CrossMarginAccount {
    address[] borrowTokens;
    mapping(address => uint256) borrowed;
    mapping(address => uint256) borrowedYieldQuotientsFP;
    address[] holdingTokens;
    mapping(address => uint256) holdings;
    mapping(address => bool) holdsToken;
}

contract CrossMarginTrading is RoleAware, Ownable {
    event LiquidationShortfall(uint256 amount);

    uint256 public leverage;
    uint256 public liquidationThresholdPercent;
    mapping(address => CrossMarginAccount) marginAccounts;

    constructor(address _roles) RoleAware(_roles) Ownable() {
        liquidationThresholdPercent = 20;
    }

    function getHoldingAmounts(address trader)
        external
        view
        returns (
            address[] memory holdingTokens,
            uint256[] memory holdingAmounts
        )
    {
        CrossMarginAccount storage account = marginAccounts[trader];
        holdingTokens = account.holdingTokens;

        holdingAmounts = new uint256[](account.holdingTokens.length);
        for (uint256 idx = 0; holdingTokens.length > idx; idx++) {
            address tokenAddress = holdingTokens[idx];
            holdingAmounts[idx] = account.holdings[tokenAddress];
        }

        (holdingTokens, holdingAmounts);
    }

    function getBorrowAmounts(address trader)
        external
        view
        returns (address[] memory borrowTokens, uint256[] memory borrowAmounts)
    {
        CrossMarginAccount storage account = marginAccounts[trader];
        borrowTokens = account.borrowTokens;

        borrowAmounts = new uint256[](account.borrowTokens.length);
        for (uint256 idx = 0; borrowTokens.length > idx; idx++) {
            address tokenAddress = borrowTokens[idx];
            borrowAmounts[idx] = Lending(lending()).viewBorrowInterest(
                account.borrowed[tokenAddress],
                tokenAddress,
                account.borrowedYieldQuotientsFP[tokenAddress]
            );
        }

        (borrowTokens, borrowAmounts);
    }

    function setLeverage(uint256 _leverage) external onlyOwner {
        leverage = _leverage;
    }

    function setLiquidationThresholdPercent(uint256 threshold)
        external
        onlyOwner
    {
        liquidationThresholdPercent = threshold;
    }

    function registerDeposit(
        address trader,
        address token,
        uint256 depositAmount
    ) external returns (uint256 extinguishableDebt) {
        require(
            isMarginTrader(msg.sender),
            "Calling contract not authorized to deposit"
        );
        CrossMarginAccount storage account = marginAccounts[trader];
        addHolding(account, token, depositAmount);
        if (account.borrowed[token] > 0) {
            extinguishableDebt = min(depositAmount, account.borrowed[token]);
        }
    }

    function addHolding(
        CrossMarginAccount storage account,
        address token,
        uint256 depositAmount
    ) internal {
        if (!hasHoldingToken(account, token)) {
            account.holdingTokens.push(token);
        }

        account.holdings[token] += depositAmount;
    }

    function registerBorrow(
        address trader,
        address borrowToken,
        uint256 borrowAmount
    ) external {
        require(
            isMarginTrader(msg.sender),
            "Calling contract not authorized to deposit"
        );
        CrossMarginAccount storage account = marginAccounts[trader];
        borrow(account, borrowToken, borrowAmount);
    }

    function borrow(
        CrossMarginAccount storage account,
        address borrowToken,
        uint256 borrowAmount
    ) internal {
        if (!hasBorrowedToken(account, borrowToken)) {
            account.borrowTokens.push(borrowToken);

            account.borrowedYieldQuotientsFP[borrowToken] = Lending(lending())
                .viewBorrowingYield(borrowToken);
        } else {
            account.borrowed[borrowToken] = Lending(lending())
                .applyBorrowInterest(
                account.borrowed[borrowToken],
                borrowToken,
                account.borrowedYieldQuotientsFP[borrowToken]
            );
        }
        account.borrowed[borrowToken] += borrowAmount;
        addHolding(account, borrowToken, borrowAmount);

        require(positiveBalance(account), "Can't borrow: insufficient balance");
    }

    function registerWithdrawal(
        address trader,
        address withdrawToken,
        uint256 withdrawAmount
    ) external {
        require(
            isMarginTrader(msg.sender),
            "Calling contract not authorized to deposit"
        );
        CrossMarginAccount storage account = marginAccounts[trader];

        // throws on underflow
        account.holdings[withdrawToken] =
            account.holdings[withdrawToken] -
            withdrawAmount;
        require(
            positiveBalance(account),
            "Account balance is too low to withdraw"
        );
    }

    function positiveBalance(CrossMarginAccount storage account)
        internal
        returns (bool)
    {
        uint256 loan = loanInPeg(account);
        uint256 holdings = holdingsInPeg(account);
        // The following condition should hold:
        // holdings / loan >= (leverage + 1) / leverage
        // =>
        return holdings * (leverage + 1) >= loan * leverage;
    }

    function registerPayOff(
        address trader,
        address debtToken,
        uint256 extinguishAmount
    ) external {
        require(
            isMarginTrader(msg.sender),
            "Calling contract not authorized to deposit"
        );
        extinguishDebt(marginAccounts[trader], debtToken, extinguishAmount);
    }

    function extinguishDebt(
        CrossMarginAccount storage account,
        address debtToken,
        uint256 extinguishAmount
    ) internal {
        // will throw if insufficient funds
        account.borrowed[debtToken] = Lending(lending()).applyBorrowInterest(
            account.borrowed[debtToken],
            debtToken,
            account.borrowedYieldQuotientsFP[debtToken]
        );
        account.borrowed[debtToken] =
            account.borrowed[debtToken] -
            extinguishAmount;
        account.holdings[debtToken] =
            account.holdings[debtToken] -
            extinguishAmount;
    }

    function hasHoldingToken(CrossMarginAccount storage account, address token)
        internal
        view
        returns (bool)
    {
        return account.holdsToken[token];
    }

    function hasBorrowedToken(CrossMarginAccount storage account, address token)
        internal
        view
        returns (bool)
    {
        return account.borrowedYieldQuotientsFP[token] > 0;
    }

    function loanInPeg(CrossMarginAccount storage account)
        internal
        returns (uint256)
    {
        return
            sumTokensInPegWithYield(
                account.borrowTokens,
                account.borrowed,
                account.borrowedYieldQuotientsFP
            );
    }

    function holdingsInPeg(CrossMarginAccount storage account)
        internal
        returns (uint256)
    {
        return sumTokensInPeg(account.holdingTokens, account.holdings);
    }

    function marginCallable(CrossMarginAccount storage account)
        internal
        returns (bool)
    {
        uint256 loan = loanInPeg(account);
        uint256 holdings = holdingsInPeg(account);
        // The following should hold:
        // holdings / loan >= (leverage + liquidationThresholdPercent / 100) / leverage
        // =>
        return
            holdings * leverage * 100 >=
            (100 * leverage + liquidationThresholdPercent) * loan;
    }

    function canBorrow(
        CrossMarginAccount storage account,
        address token,
        uint256 amount
    ) internal view returns (bool) {
        return account.holdings[token] >= amount;
    }

    function getTradeBorrowAmount(
        address trader,
        address token,
        uint256 amount
    ) external view returns (uint256 borrowAmount) {
        require(
            isMarginTrader(msg.sender),
            "Calling contract is not an authorized margin trader"
        );
        CrossMarginAccount storage account = marginAccounts[trader];
        borrowAmount = amount - account.holdings[token];
        require(
            canBorrow(account, token, borrowAmount),
            "Can't borrow full amount"
        );
    }

    function registerTradeAndBorrow(
        address trader,
        address tokenFrom,
        address tokenTo,
        uint256 inAmount,
        uint256 outAmount
    ) external returns (uint256 borrowAmount) {
        require(
            isMarginTrader(msg.sender),
            "Calling contract is not an authorized margin trader agent"
        );

        CrossMarginAccount storage account = marginAccounts[trader];
        uint256 sellAmount = inAmount;
        if (inAmount > account.holdings[tokenFrom]) {
            sellAmount = account.holdings[tokenFrom];
            borrowAmount = inAmount - sellAmount;
            borrow(account, tokenFrom, borrowAmount);
        }
        adjustAmounts(account, tokenFrom, tokenTo, sellAmount, outAmount);
    }

    function sumTokensInPeg(
        address[] storage tokens,
        mapping(address => uint256) storage amounts
    ) internal returns (uint256 totalPeg) {
        for (uint256 tokenId = 0; tokenId < tokens.length; tokenId++) {
            address token = tokens[tokenId];
            totalPeg += Price(price()).getUpdatedPriceInPeg(
                token,
                amounts[token]
            );
        }
    }

    function sumTokensInPegWithYield(
        address[] storage tokens,
        mapping(address => uint256) storage amounts,
        mapping(address => uint256) storage yieldQuotientsFP
    ) internal returns (uint256 totalPeg) {
        for (uint256 tokenId = 0; tokenId < tokens.length; tokenId++) {
            address token = tokens[tokenId];
            totalPeg += yieldTokenInPeg(
                token,
                amounts[token],
                yieldQuotientsFP
            );
        }
    }

    function yieldTokenInPeg(
        address token,
        uint256 amount,
        mapping(address => uint256) storage yieldQuotientsFP
    ) internal returns (uint256) {
        uint256 yield = Lending(lending()).viewBorrowingYield(token);
        // 1 * FP / FP = 1
        uint256 amountInToken = (amount * yield) / yieldQuotientsFP[token];
        return Price(price()).getUpdatedPriceInPeg(token, amountInToken);
    }

    function adjustAmounts(
        CrossMarginAccount storage account,
        address fromToken,
        address toToken,
        uint256 soldAmount,
        uint256 boughtAmount
    ) internal {
        account.holdings[fromToken] = account.holdings[fromToken] - soldAmount;
        addHolding(account, toToken, boughtAmount);
    }

    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a > b) {
            return b;
        } else {
            return a;
        }
    }

    struct Liquidation {
        uint256 buy;
        uint256 sell;
        uint256 blockNum;
    }
    mapping(address => Liquidation) liquidationAmounts;
    address[] sellTokens;
    address[] buyTokens;
    address[] tradersToLiquidate;

    struct MCRecord {
        uint256 blockNum;
        uint256 amount;
        address stakeAttacker;
    }
    mapping(address => MCRecord) stakeAttackRecords;

    uint256 mcAttackWindow = 80;

    function calcLiquidationAmounts(
        address[] memory liquidationCandidates,
        bool isAuthorized
    ) internal returns (uint256 attackReturns) {
        sellTokens = new address[](0);
        buyTokens = new address[](0);
        tradersToLiquidate = new address[](0);
        // TODO test
        for (
            uint256 traderIndex = 0;
            liquidationCandidates.length > traderIndex;
            traderIndex++
        ) {
            address traderAddress = liquidationCandidates[traderIndex];
            CrossMarginAccount storage account = marginAccounts[traderAddress];
            if (marginCallable(account)) {
                // TODO optimize maybe put in the whole account?
                // TODO unique?
                tradersToLiquidate.push(traderAddress);
                for (
                    uint256 sellIdx = 0;
                    account.holdingTokens.length > sellIdx;
                    sellIdx++
                ) {
                    address token = account.holdingTokens[sellIdx];
                    Liquidation storage liquidation = liquidationAmounts[token];
                    if (liquidation.blockNum != block.number) {
                        // TODO delete liquidationAmounts at end of call?
                        liquidation.sell = account.holdings[token];
                        liquidation.buy = 0;
                        liquidation.blockNum = block.number;
                        sellTokens.push(token);
                    } else {
                        liquidation.sell += account.holdings[token];
                    }
                }
                for (
                    uint256 buyIdx = 0;
                    account.borrowTokens.length > buyIdx;
                    buyIdx++
                ) {
                    address token = account.borrowTokens[buyIdx];
                    Liquidation storage liquidation = liquidationAmounts[token];

                    uint256 yield =
                        Lending(lending()).viewBorrowingYield(token);
                    uint256 loanAmount =
                        (account.borrowed[token] * yield) /
                            account.borrowedYieldQuotientsFP[token];

                    if (liquidation.blockNum != block.number) {
                        liquidation.sell = 0;
                        liquidation.buy = loanAmount;
                        liquidation.blockNum = block.number;
                        buyTokens.push(token);
                    } else {
                        liquidation.buy += loanAmount;
                    }
                }
            }
            MCRecord storage mcRecord = stakeAttackRecords[traderAddress];
            if (mcRecord.amount > 0 && isAuthorized) {
                // validate attack records, if any
                uint256 blockDif =
                    min(1 + block.number - mcRecord.blockNum, mcAttackWindow);
                uint256 attackerCut =
                    (blockDif * mcRecord.amount) / mcAttackWindow;
                Fund(fund()).withdraw(
                    Price(price()).peg(),
                    mcRecord.stakeAttacker,
                    attackerCut
                );
                attackReturns += mcRecord.amount - attackerCut;
                mcRecord.amount = 0;
                mcRecord.stakeAttacker = address(0);
                mcRecord.blockNum = 0;
            }
        }
    }

    function liquidateFromPeg() internal returns (uint256 pegAmount) {
        for (uint256 tokenIdx = 0; buyTokens.length > tokenIdx; tokenIdx++) {
            address buyToken = buyTokens[tokenIdx];
            Liquidation storage liq = liquidationAmounts[buyToken];
            if (liq.buy > liq.sell) {
                pegAmount += Price(price()).liquidateToPeg(
                    buyToken,
                    liq.buy - liq.sell
                );
            }
        }
    }

    function liquidateToPeg() internal returns (uint256 pegAmount) {
        for (
            uint256 tokenIndex = 0;
            sellTokens.length > tokenIndex;
            tokenIndex++
        ) {
            address token = sellTokens[tokenIndex];
            Liquidation storage liq = liquidationAmounts[token];
            if (liq.sell > liq.buy) {
                uint256 sellAmount = liq.sell - liq.buy;
                pegAmount += Price(price()).liquidateToPeg(token, sellAmount);
            }
        }
    }

    function deleteAccount(CrossMarginAccount storage account) internal {
        for (
            uint256 borrowIdx = 0;
            account.borrowTokens.length > borrowIdx;
            borrowIdx++
        ) {
            address borrowToken = account.borrowTokens[borrowIdx];
            account.borrowed[borrowToken] = 0;
            account.borrowedYieldQuotientsFP[borrowToken] = 0;
        }
        for (
            uint256 holdingIdx = 0;
            account.holdingTokens.length > holdingIdx;
            holdingIdx++
        ) {
            address holdingToken = account.holdingTokens[holdingIdx];
            account.holdings[holdingToken] = 0;
            account.holdsToken[holdingToken] = false;
        }
        delete account.borrowTokens;
        delete account.holdingTokens;
    }

    function callMargin(
        address[] memory liquidationCandidates,
        address currentCaller,
        bool isAuthorized
    ) external returns (uint256 marginCallerCut) {
        require(
            isMarginCaller(msg.sender),
            "Calling address doesn't have margin caller role"
        );

        //(address[] memory sellTokens,
        //address[] memory buyTokens,
        // address[] memory tradersToLiquidate) =
        uint256 attackReturns2Authorized =
            calcLiquidationAmounts(liquidationCandidates, isAuthorized);
        marginCallerCut += attackReturns2Authorized;

        uint256 sale2pegAmount = liquidateToPeg();
        uint256 peg2targetCost = liquidateFromPeg();
        // TODO add the mcCut to this
        if (peg2targetCost > sale2pegAmount) {
            emit LiquidationShortfall(peg2targetCost - sale2pegAmount);
        }

        for (
            uint256 traderIdx = 0;
            tradersToLiquidate.length > traderIdx;
            traderIdx++
        ) {
            address traderAddress = tradersToLiquidate[traderIdx];
            CrossMarginAccount storage account = marginAccounts[traderAddress];

            uint256 holdingsValue = holdingsInPeg(account);
            uint256 borrowValue = loanInPeg(account);
            // half of the liquidation threshold
            uint256 mcCut4account =
                (borrowValue * liquidationThresholdPercent) /
                    100 /
                    leverage /
                    2;
            if (isAuthorized) {
                marginCallerCut += mcCut4account;
            } else {
                // This could theoretically lead to a previous attackers
                // record being overwritten, but only if the trader restarts
                // their account and goes back into the red within the short time window
                // which would be a costly attack requiring collusion without upside
                MCRecord storage mcRecord = stakeAttackRecords[traderAddress];
                mcRecord.amount = mcCut4account;
                mcRecord.stakeAttacker = currentCaller;
                mcRecord.blockNum = block.number;
            }

            if (holdingsValue >= mcCut4account + borrowValue) {
                // send remaining funds back to trader
                Fund(fund()).withdraw(
                    Price(price()).peg(),
                    traderAddress,
                    holdingsValue - borrowValue - mcCut4account
                );
            } else {
                uint256 shortfall =
                    (borrowValue + mcCut4account) - holdingsValue;
                emit LiquidationShortfall(shortfall);
            }

            deleteAccount(account);
        }
    }
}
