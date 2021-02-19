pragma solidity ^0.7.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";

import "./Fund.sol";
import "./Lending.sol";
import "./RoleAware.sol";
import "./MarginRouter.sol";
import "./Price.sol";

// Goal: all external functions only accessible to margintrader role
// except for view functions of course

struct MarginAccount {
    address[] borrowTokens;
    mapping(address => uint256) borrowed;
    mapping(address => uint256) borrowedYieldQuotientsFP;
    address[] holdingTokens;
    mapping(address => uint256) holdings;
    mapping(address => bool) holdsToken;
}

contract MarginTrading is RoleAware, Ownable {
    using SafeMath for uint256;

    uint256 public leverage;
    uint256 public liquidationThresholdPercent;
    mapping(address => MarginAccount) marginAccounts;

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
        MarginAccount storage account = marginAccounts[trader];
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
        MarginAccount storage account = marginAccounts[trader];
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
        MarginAccount storage account = marginAccounts[trader];
        addHolding(account, token, depositAmount);
        if (account.borrowed[token] > 0) {
            extinguishableDebt = min(depositAmount, account.borrowed[token]);
        }
    }

    function addHolding(
        MarginAccount storage account,
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
        MarginAccount storage account = marginAccounts[trader];
        borrow(account, borrowToken, borrowAmount);
    }

    function borrow(
        MarginAccount storage account,
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
        MarginAccount storage account = marginAccounts[trader];

        // SafeMath throws on underflow
        account.holdings[withdrawToken] = account.holdings[withdrawToken].sub(
            withdrawAmount
        );
        require(
            positiveBalance(account),
            "Account balance is too low to withdraw"
        );
    }

    function positiveBalance(MarginAccount storage account)
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
        MarginAccount storage account,
        address debtToken,
        uint256 extinguishAmount
    ) internal {
        // SafeMath will throw if insufficient funds
        account.borrowed[debtToken] = Lending(lending()).applyBorrowInterest(
            account.borrowed[debtToken],
            debtToken,
            account.borrowedYieldQuotientsFP[debtToken]
        );
        account.borrowed[debtToken] = account.borrowed[debtToken].sub(
            extinguishAmount
        );
        account.holdings[debtToken] = account.holdings[debtToken].sub(
            extinguishAmount
        );
    }

    function hasHoldingToken(MarginAccount storage account, address token)
        internal
        view
        returns (bool)
    {
        return account.holdsToken[token];
    }

    function hasBorrowedToken(MarginAccount storage account, address token)
        internal
        view
        returns (bool)
    {
        return account.borrowedYieldQuotientsFP[token] > 0;
    }

    function loanInPeg(MarginAccount storage account)
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

    function holdingsInPeg(MarginAccount storage account)
        internal
        returns (uint256)
    {
        return sumTokensInPeg(account.holdingTokens, account.holdings);
    }

    function marginCallable(MarginAccount storage account)
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
        MarginAccount storage account,
        address token,
        uint256 amount
    ) internal view returns (bool) {
        return account.holdings[token] >= amount;
    }

    function getTradeBorrowAmount(
        address trader,
        address token,
        uint256 amount
    ) external returns (uint256 borrowAmount) {
        require(
            isMarginTrader(msg.sender),
            "Calling contract is not an authorized margin trader"
        );
        MarginAccount storage account = marginAccounts[trader];
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

        MarginAccount storage account = marginAccounts[trader];
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
        MarginAccount storage account,
        address fromToken,
        address toToken,
        uint256 soldAmount,
        uint256 boughtAmount
    ) internal {
        account.holdings[fromToken] = account.holdings[fromToken].sub(
            soldAmount
        );
        addHolding(account, toToken, boughtAmount);
    }

    function min(uint256 a, uint256 b) internal returns (uint256) {
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

    // TODO bake records after margin calling
    struct MCRecord {
        uint256 blockNum;
        uint256 amount;
        uint256 stakeAttacker;
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
            MarginAccount storage account = marginAccounts[traderAddress];
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
                        // TODO delete liquidationAmounts at end of call
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
                // TODO send attackerCut to mcRecord.stakeAttacker
                attackReturns += mcRecord.amount - attackerCut;
            }
        }
    }

    function calcLiquidationTargetCosts()
        internal
        view
        returns (uint256[] memory pegAmounts)
    {
        pegAmounts = new uint256[](buyTokens.length);
        // TODO calc how much it would cost for every buy
    }

    function liquidateToPeg() internal returns (uint256 pegAmount) {
        for (
            uint256 tokenIndex = 0;
            sellTokens.length > tokenIndex;
            tokenIndex++
        ) {
            uint256 sellAmount =
                liquidationAmounts[sellTokens[tokenIndex]].sell;
            // sell TODO
            pegAmount += 0;
        }
    }

    function deleteAccount(MarginAccount storage account) internal {
        // TODO
    }

    function holdings2Peg(MarginAccount storage account)
        internal
        returns (uint256 pegAmount)
    {
        // TODO work with price module
    }

    function callMargin(
        address[] memory liquidationCandidates,
        address responsibleStaker,
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
        // TODO distribute attackReturns
        uint256 attackReturns =
            calcLiquidationAmounts(liquidationCandidates, isAuthorized);

        uint256 sale2pegAmount = liquidateToPeg();
        uint256[] memory peg2targetCosts = calcLiquidationTargetCosts();

        for (
            uint256 traderIdx = 0;
            tradersToLiquidate.length > traderIdx;
            traderIdx++
        ) {
            address traderAddress = tradersToLiquidate[traderIdx];
            MarginAccount storage account = marginAccounts[traderAddress];

            uint256 holdingsValue = holdings2Peg(account);
            uint256 borrowValue = loanInPeg(account);
            // half of the liquidation threshold
            uint256 mcCut4account =
                (borrowValue * liquidationThresholdPercent) /
                    100 /
                    leverage /
                    2;
            marginCallerCut += mcCut4account;

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
            }

            deleteAccount(account);
        }
    }
}
