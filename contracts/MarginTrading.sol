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
    address WETH;

    constructor(address _WETH, address _roles) RoleAware(_roles) Ownable() {
        WETH = _WETH;
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
        uint256 loan = loanInETH(account);
        uint256 holdings = holdingsInETH(account);
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

    function loanInETH(MarginAccount storage account)
        internal
        returns (uint256)
    {
        return
            sumTokensInETHWithYield(
                account.borrowTokens,
                account.borrowed,
                account.borrowedYieldQuotientsFP
            );
    }

    function holdingsInETH(MarginAccount storage account)
        internal
        view
        returns (uint256)
    {
        return sumTokensInETH(account.holdingTokens, account.holdings);
    }

    function marginCallable(MarginAccount storage account)
        internal
        returns (bool)
    {
        uint256 loan = loanInETH(account);
        uint256 holdings = holdingsInETH(account);
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

    function sellPath(address sourceToken, address targetToken)
        internal
        view
        returns (address[] memory)
    {
        if (targetToken == WETH || sourceToken == WETH) {
            // TODO both source and target the same?
            address[] memory path = new address[](2);
            path[0] = sourceToken;
            path[1] = targetToken;
            return path;
        } else {
            address[] memory path = new address[](3);
            path[0] = sourceToken;
            path[1] = WETH;
            path[2] = targetToken;
            return path;
        }
    }

    function spotConversionAmount(
        address inToken,
        address outToken,
        uint256 inAmount
    ) internal returns (uint256) {
        address[] memory path = sellPath(inToken, outToken);
        uint256[] memory pathAmounts =
            MarginRouter(router()).getAmountsOut(AMM.uni, inAmount, path);
        return pathAmounts[pathAmounts.length - 1];
    }

    function ethSpotPrice(address token, uint256 amount)
        internal
        view
        returns (uint256)
    {
        if (token == WETH) {
            return 1;
        } else {
            address[] memory path = new address[](2);
            path[0] = token;
            path[1] = WETH;
            uint256[] memory pathAmounts =
                MarginRouter(router()).getAmountsOut(AMM.uni, amount, path);
            return pathAmounts[pathAmounts.length - 1];
        }
    }

    function sumTokensInETH(
        address[] storage tokens,
        mapping(address => uint256) storage amounts
    ) internal view returns (uint256 totalETH) {
        for (uint256 tokenId = 0; tokenId < tokens.length; tokenId++) {
            address token = tokens[tokenId];
            totalETH += ethSpotPrice(token, amounts[token]);
        }
    }

    function sumTokensInETHWithYield(
        address[] storage tokens,
        mapping(address => uint256) storage amounts,
        mapping(address => uint256) storage yieldQuotientsFP
    ) internal returns (uint256 totalETH) {
        for (uint256 tokenId = 0; tokenId < tokens.length; tokenId++) {
            address token = tokens[tokenId];
            totalETH += yieldTokenInETH(
                token,
                amounts[token],
                yieldQuotientsFP
            );
        }
    }

    function yieldTokenInETH(
        address token,
        uint256 amount,
        mapping(address => uint256) storage yieldQuotientsFP
    ) internal returns (uint256) {
        uint256 yield = Lending(lending()).viewBorrowingYield(token);
        // 1 * FP / FP = 1
        uint256 amountInToken = (amount * yield) / yieldQuotientsFP[token];
        return ethSpotPrice(token, amountInToken);
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
    address[] volatileBuyTokens;
    address[] volatileSellTokens;

    function calcLiquidationAmounts(address[] memory liquidationCandidates)
        internal
        returns (
            address[] memory sellTokens,
            address[] memory buyTokens,
            address[] memory tradersToLiquidate
        )
    {
        for (
            uint256 traderIndex = 0;
            liquidationCandidates.length > traderIndex;
            traderIndex++
        ) {
            // TODO
        }
    }

    function calcLiquidationTargetCosts(address[] memory buyTokens)
        internal
        view
        returns (uint256[] memory pegAmounts)
    {
        pegAmounts = new uint256[](buyTokens.length);
        // TODO calc how much it would cost for every buy
    }

    function liquidateToPeg(address[] memory sellTokens)
        internal
        returns (uint256 pegAmount)
    {
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

    function holdings2Peg(MarginAccount storage account)
        internal
        returns (uint256 pegAmount)
    {
        // TODO work with price module
    }

    function clearVolatileArray(address[] storage volatileTokens) internal {
        while (volatileTokens.length > 0) {
            volatileTokens.pop();
        }
    }

    function updateVolatileArrays(
        address[] memory sellTokens,
        address[] memory buyTokens
    ) internal {
        clearVolatileArray(volatileSellTokens);
        clearVolatileArray(volatileBuyTokens);

        for (uint256 idx = 0; sellTokens.length > idx; idx++) {
            // TODO check if price went down bigly and add to volatileSelltokens
        }

        for (uint256 idx = 0; buyTokens.length > idx; idx++) {
            // TODO check if price went up bigly and add to volatileBuytokens
        }
    }

    function callMargin(address[] memory liquidationCandidates)
        external
        returns (uint256)
    {
        require(
            isMarginCaller(msg.sender),
            "Calling address doesn't have margin caller role"
        );

        (
            address[] memory sellTokens,
            address[] memory buyTokens,
            address[] memory tradersToLiquidate
        ) = calcLiquidationAmounts(liquidationCandidates);

        uint256 sale2pegAmount = liquidateToPeg(sellTokens);
        uint256[] memory peg2targetCosts =
            calcLiquidationTargetCosts(buyTokens);
        updateVolatileArrays(sellTokens, buyTokens);

        uint256 marginCallerCut = 0;
        for (
            uint256 traderIdx = 0;
            tradersToLiquidate.length > traderIdx;
            traderIdx++
        ) {
            MarginAccount storage account =
                marginAccounts[tradersToLiquidate[traderIdx]];

            uint256 holdingsValue = holdings2Peg(account);
            uint256 borrowValue = loanInETH(account);
            // half of the liquidation threshold
            uint256 mcCut4account =
                (borrowValue * liquidationThresholdPercent) /
                    100 /
                    leverage /
                    2;
            marginCallerCut += mcCut4account;
            if (holdingsValue >= mcCut4account + borrowValue) {
                // TODO send back remainder to trader
            } else {
                uint256 shortfall =
                    (borrowValue + mcCut4account) - holdingsValue;
                // find the bag holder
                // iterate over tokens by losses
                // weighted sum
                uint256[] memory sellWeights =
                    new uint256[](volatileSellTokens.length);
                uint256[] memory buyWeights =
                    new uint256[](volatileBuyTokens.length);
                uint256 totalWeights = 0;

                for (
                    uint256 sellIdx = 0;
                    volatileSellTokens.length > sellIdx;
                    sellIdx++
                ) {
                    address token = volatileSellTokens[sellIdx];
                    if (account.holdsToken[token]) {
                        uint256 maxDrop = 0; // TODO
                        uint256 weight =
                            maxDrop *
                                ethSpotPrice(token, account.holdings[token]);
                        sellWeights[sellIdx] = weight;
                        totalWeights += weight;
                    }
                }

                for (
                    uint256 buyIdx = 0;
                    volatileBuyTokens.length > buyIdx;
                    buyIdx++
                ) {
                    address token = volatileBuyTokens[buyIdx];
                    if (account.borrowed[token] > 0) {
                        uint256 maxRise = 0; // TODO
                        uint256 weight =
                            maxRise *
                                yieldTokenInETH(
                                    token,
                                    account.borrowed[token],
                                    account.borrowedYieldQuotientsFP
                                );
                        buyWeights[buyIdx] = weight;
                        totalWeights += weight;
                    }
                }

                if (totalWeights > 0) {
                    for (
                        uint256 sellIdx = 0;
                        volatileSellTokens.length > sellIdx;
                        sellIdx++
                    ) {
                        if (sellWeights[sellIdx] > 0) {
                            address token = volatileSellTokens[sellIdx];
                            Price(price()).claimInsurance(
                                token,
                                (shortfall * sellWeights[sellIdx]) /
                                    totalWeights
                            );
                        }
                    }

                    for (
                        uint256 buyIdx = 0;
                        volatileBuyTokens.length > buyIdx;
                        buyIdx++
                    ) {
                        if (buyWeights[buyIdx] > 0) {
                            address token = volatileBuyTokens[buyIdx];
                            Price(price()).claimInsurance(
                                token,
                                (shortfall * buyWeights[buyIdx]) / totalWeights
                            );
                        }
                    }
                } else {
                    // TODO we have a problem and either there's a bug or margin callers didn't do their job
                    // we probably want to raise an event here, not an exception so as to not paralize margin calling
                }
            }
        }
    }
}
