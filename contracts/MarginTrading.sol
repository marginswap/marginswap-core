pragma solidity ^0.7.0;

import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/math/SafeMath.sol';

import './Fund.sol';
import './Lending.sol';
import './RoleAware.sol';
import './MarginRouter.sol';
import './Price.sol';

// Goal: all external functions only accessible to margintrader role
// except for view functions of course

struct MarginAccount {
    address[] borrowTokens;
    mapping(address => uint) borrowed;
    mapping(address => uint) borrowedYieldQuotientsFP;

    address[] holdingTokens;
    mapping(address => uint) holdings;
    mapping(address => bool) holdsToken;
}

contract MarginTrading is RoleAware, Ownable {
    using SafeMath for uint;

    uint public leverage;
    uint public liquidationThresholdPercent;
    mapping(address => MarginAccount) marginAccounts;

    constructor(address _roles) RoleAware(_roles) Ownable() {
        liquidationThresholdPercent = 20;
    }

    function getHoldingAmounts(address trader) external view
        returns (address[] memory holdingTokens, uint[] memory holdingAmounts) {
        MarginAccount storage account = marginAccounts[trader];
        holdingTokens = account.holdingTokens;

        holdingAmounts = new uint[] (account.holdingTokens.length);
        for (uint idx = 0; holdingTokens.length > idx; idx++) {
            address tokenAddress = holdingTokens[idx];
            holdingAmounts[idx] = account.holdings[tokenAddress];
        }  
    }

    function setLeverage(uint _leverage) external onlyOwner {
        leverage = _leverage;
    }

    function setLiquidationThresholdPercent(uint threshold) external onlyOwner {
        liquidationThresholdPercent = threshold;
    }

    function registerDeposit(address trader,
                             address token,
                             uint depositAmount) external returns (uint extinguishableDebt) {
        require(isMarginTrader(msg.sender), "Calling contract not authorized to deposit");
        MarginAccount storage account = marginAccounts[trader];
        addHolding(account, token, depositAmount);
        if (account.borrowed[token] > 0) {
            extinguishableDebt = min(depositAmount, account.borrowed[token]);
        }
    }

    function addHolding(MarginAccount storage account, address token, uint depositAmount) internal {
        if (!hasHoldingToken(account, token)) {
            account.holdingTokens.push(token);
        }

        account.holdings[token] += depositAmount;
    }
    
    function registerBorrow(address trader, address borrowToken, uint borrowAmount) external {
        require(isMarginTrader(msg.sender), "Calling contract not authorized to deposit");
        MarginAccount storage account = marginAccounts[trader];
        borrow(account, borrowToken, borrowAmount);
    }

    function borrow(MarginAccount storage account, address borrowToken, uint borrowAmount) internal {
        if (!hasBorrowedToken(account, borrowToken)) {
            account.borrowTokens.push(borrowToken);


            account.borrowedYieldQuotientsFP[borrowToken] = Lending(lending())
                .viewBorrowingYield(borrowToken);
        } else {
            account.borrowed[borrowToken] = Lending(lending())
                .applyBorrowInterest(account.borrowed[borrowToken],
                                     borrowToken,
                                     account.borrowedYieldQuotientsFP[borrowToken]);
        }
        account.borrowed[borrowToken] += borrowAmount;
        addHolding(account, borrowToken, borrowAmount);

        require(positiveBalance(account),
                "Can't borrow: insufficient balance");
    }


    function registerWithdrawal(address trader, address withdrawToken, uint withdrawAmount) external {
        require(isMarginTrader(msg.sender), "Calling contract not authorized to deposit");
        MarginAccount storage account = marginAccounts[trader];

        // SafeMath throws on underflow 
        account.holdings[withdrawToken] = account.holdings[withdrawToken].sub(withdrawAmount);
        require(positiveBalance(account),
                "Account balance is too low to withdraw");
    }

    function positiveBalance(MarginAccount storage account) internal returns (bool) {
        uint loan = loanInPeg(account);
        uint holdings = holdingsInPeg(account);
        // The following condition should hold:
        // holdings / loan >= (leverage + 1) / leverage
        // =>
        return holdings * (leverage + 1) >= loan * leverage;
    }

    function registerPayOff(address trader, address debtToken, uint extinguishAmount) external {
        require(isMarginTrader(msg.sender), "Calling contract not authorized to deposit");
        extinguishDebt(marginAccounts[trader], debtToken, extinguishAmount);
    }

    function extinguishDebt(MarginAccount storage account,
                            address debtToken,
                            uint extinguishAmount) internal {
        // SafeMath will throw if insufficient funds
        account.borrowed[debtToken] = Lending(lending())
            .applyBorrowInterest(account.borrowed[debtToken],
                                 debtToken,
                                 account.borrowedYieldQuotientsFP[debtToken]);
        account.borrowed[debtToken] = account.borrowed[debtToken].sub(extinguishAmount);
        account.holdings[debtToken] = account.holdings[debtToken].sub(extinguishAmount);
    }

    function hasHoldingToken(MarginAccount storage account, address token) internal view returns (bool) {
        return account.holdsToken[token];
    }

    function hasBorrowedToken(MarginAccount storage account, address token) internal view returns (bool) {
        return account.borrowedYieldQuotientsFP[token] > 0;
    }
    
    function loanInPeg(MarginAccount storage account) internal returns (uint) {
        return sumTokensInPegWithYield(account.borrowTokens,
                                       account.borrowed,
                                       account.borrowedYieldQuotientsFP);
    }

    function holdingsInPeg(MarginAccount storage account) internal returns (uint) {
        return sumTokensInPeg(account.holdingTokens, account.holdings);
    }

    function marginCallable(MarginAccount storage account) internal returns (bool) {
        uint loan = loanInPeg(account);
        uint holdings = holdingsInPeg(account);
        // The following should hold:
        // holdings / loan >= (leverage + liquidationThresholdPercent / 100) / leverage
        // =>
        return holdings * leverage * 100 >= (100 * leverage + liquidationThresholdPercent) * loan;
    }

    function canBorrow(MarginAccount storage account, address token, uint amount)
        internal view returns (bool) {
        return account.holdings[token] >= amount;
    }

    function getTradeBorrowAmount(address trader, address token, uint amount)
        external returns (uint borrowAmount) {
        require(isMarginTrader(msg.sender), "Calling contract is not an authorized margin trader");
        MarginAccount storage account = marginAccounts[trader];
        borrowAmount = amount - account.holdings[token];
        require(canBorrow(account, token, borrowAmount), "Can't borrow full amount");
    }

    function registerTradeAndBorrow(address trader,
                                    address tokenFrom,
                                    address tokenTo,
                                    uint inAmount,
                                    uint outAmount) external returns (uint borrowAmount) {
        require(isMarginTrader(msg.sender), "Calling contract is not an authorized margin trader agent");

        MarginAccount storage account = marginAccounts[trader];
        uint sellAmount = inAmount;
        if (inAmount > account.holdings[tokenFrom]) {
            sellAmount = account.holdings[tokenFrom];
            borrowAmount =  inAmount - sellAmount;
            borrow(account, tokenFrom, borrowAmount);
        }
        adjustAmounts(account, tokenFrom, tokenTo, sellAmount, outAmount);
    }

    function sumTokensInPeg(address[] storage tokens, mapping(address => uint) storage amounts)
        internal returns (uint totalPeg) {
        for (uint tokenId = 0; tokenId < tokens.length; tokenId++) {
            address token = tokens[tokenId];
            totalPeg += Price(price()).getUpdatedPriceInPeg(token, amounts[token]);
        }
    }
    
    function sumTokensInPegWithYield(address[] storage tokens,
                                     mapping(address => uint) storage amounts,
                                     mapping(address => uint) storage yieldQuotientsFP)
        internal returns (uint totalPeg) {
        for (uint tokenId = 0; tokenId < tokens.length; tokenId++) {
            address token = tokens[tokenId];
            totalPeg += yieldTokenInPeg(token, amounts[token], yieldQuotientsFP);
        }
    }

    function yieldTokenInPeg(address token, uint amount, mapping(address => uint) storage yieldQuotientsFP)
        internal returns (uint) {
        uint yield = Lending(lending()).viewBorrowingYield(token);
        // 1 * FP / FP = 1
        uint amountInToken = (amount * yield) / yieldQuotientsFP[token];
        return Price(price()).getUpdatedPriceInPeg(token, amountInToken);
    }

    function adjustAmounts(MarginAccount storage account,
                           address fromToken,
                           address toToken,
                           uint soldAmount,
                           uint boughtAmount) internal {
        account.holdings[fromToken] = account.holdings[fromToken].sub(soldAmount);
        addHolding(account, toToken, boughtAmount);
    }

    function min(uint a, uint b) internal returns (uint) {
        if (a > b) {
            return b;
        } else {
            return a;
        }
    }

    struct Liquidation {
        uint buy;
        uint sell;
        uint blockNum;
    }
    mapping(address => Liquidation) liquidationAmounts;
    address[] volatileBuyTokens;
    address[] volatileSellTokens;

    address[] sellTokens;
    address[] buyTokens;
    address[] tradersToLiquidate;


    // TODO bake records after margin calling
    struct MCRecord {
        uint blockNum;
        uint amount;
        uint stakeAttacker;
    }
    mapping(address => MCRecord) stakeAttackRecords;

    uint mcAttackWindow = 80;

    function calcLiquidationAmounts(address[] memory liquidationCandidates, bool isAuthorized)
        internal returns (uint attackReturns) {
        sellTokens = new address[](0);
        buyTokens = new address[](0);
        tradersToLiquidate = new address[](0);
        // TODO test
        for (uint traderIndex = 0; liquidationCandidates.length > traderIndex; traderIndex++) {
            address traderAddress = liquidationCandidates[traderIndex];
            MarginAccount storage account = marginAccounts[traderAddress];
            if (marginCallable(account)) {
                // TODO optimize maybe put in the whole account?
                // TODO unique?
                tradersToLiquidate.push(traderAddress);
                for(uint sellIdx = 0; account.holdingTokens.length > sellIdx; sellIdx++) {
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
                for (uint buyIdx = 0; account.borrowTokens.length > buyIdx; buyIdx++) {
                    address token = account.borrowTokens[buyIdx];
                    Liquidation storage liquidation = liquidationAmounts[token];

                    uint yield = Lending(lending()).viewBorrowingYield(token);
                    uint loanAmount = (account.borrowed[token] * yield) / account.borrowedYieldQuotientsFP[token];

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
                uint blockDif = min(1 + block.number - mcRecord.blockNum, mcAttackWindow);
                uint attackerCut = blockDif * mcRecord.amount / mcAttackWindow;
                // TODO send attackerCut to mcRecord.stakeAttacker
                attackReturns += mcRecord.amount - attackerCut;
            }
        }
    }

    function calcLiquidationTargetCosts() internal view
        returns (uint[] memory pegAmounts) {
        pegAmounts = new uint[](buyTokens.length);
        // TODO calc how much it would cost for every buy
    }

    function liquidateToPeg() internal returns (uint pegAmount) {
        for (uint tokenIndex = 0; sellTokens.length > tokenIndex; tokenIndex++) {
            uint sellAmount = liquidationAmounts[sellTokens[tokenIndex]].sell;
            // sell TODO
            pegAmount += 0;
        }
    }

    function deleteAccount(MarginAccount storage account) internal {
        // TODO
    }

    function holdings2Peg(MarginAccount storage account) internal returns (uint pegAmount) {
        // TODO work with price module
    }

    function clearVolatileArray(address[] storage volatileTokens) internal {
        while (volatileTokens.length > 0) {
            volatileTokens.pop();
        }
    }

    function updateVolatileArrays() internal {
        clearVolatileArray(volatileSellTokens);
        clearVolatileArray(volatileBuyTokens);

        for (uint idx = 0; sellTokens.length > idx; idx++) {
            // TODO check if price went down bigly and add to volatileSelltokens
        }

        for (uint idx = 0; buyTokens.length > idx; idx++) {
            // TODO check if price went up bigly and add to volatileBuytokens
        }
    }

    function callMargin(address[] memory liquidationCandidates,
                        address responsibleStaker,
                        address currentCaller,
                        bool isAuthorized) external returns (uint marginCallerCut) {
        require(isMarginCaller(msg.sender), "Calling address doesn't have margin caller role");

        //(address[] memory sellTokens,
        //address[] memory buyTokens,
        // address[] memory tradersToLiquidate) =
        // TODO distribute attackReturns
        uint attackReturns = calcLiquidationAmounts(liquidationCandidates, isAuthorized);

        uint sale2pegAmount = liquidateToPeg();
        uint[] memory peg2targetCosts = calcLiquidationTargetCosts();
        updateVolatileArrays();

        for (uint traderIdx = 0; tradersToLiquidate.length > traderIdx; traderIdx++) {
            address traderAddress = tradersToLiquidate[traderIdx];
            MarginAccount storage account = marginAccounts[traderAddress];

            uint holdingsValue = holdings2Peg(account);
            uint borrowValue = loanInPeg(account);
            // half of the liquidation threshold
            uint mcCut4account = borrowValue * liquidationThresholdPercent / 100 / leverage / 2;
            marginCallerCut += mcCut4account;

            if (holdingsValue >= mcCut4account + borrowValue) {
                // send remaining funds back to trader
                Fund(fund()).withdraw(Price(price()).peg(),
                                      traderAddress,
                                      holdingsValue - borrowValue - mcCut4account);

            } else {
                uint shortfall = (borrowValue + mcCut4account) - holdingsValue;
                // find the bag holder
                // iterate over tokens by losses
                // weighted sum
                uint[] memory sellWeights = new uint[](volatileSellTokens.length);
                uint[] memory buyWeights = new uint[](volatileBuyTokens.length);
                uint totalWeights = 0;

                for (uint sellIdx = 0; volatileSellTokens.length > sellIdx; sellIdx++) {
                    address token = volatileSellTokens[sellIdx];
                    if (account.holdsToken[token]) {
                        uint maxDrop = 0; // TODO
                        uint weight = maxDrop * Price(price()).getUpdatedPriceInPeg(token, account.holdings[token]);
                        sellWeights[sellIdx] = weight;
                        totalWeights += weight;
                    }
                }

                for (uint buyIdx = 0; volatileBuyTokens.length > buyIdx; buyIdx++) {
                    address token = volatileBuyTokens[buyIdx];
                    if (account.borrowed[token] > 0) {
                        uint maxRise = 0; // TODO
                        uint weight = maxRise * yieldTokenInPeg(token,
                                                                account.borrowed[token],
                                                                account.borrowedYieldQuotientsFP);
                        buyWeights[buyIdx] = weight;
                        totalWeights += weight;
                    }
                }

                if (totalWeights > 0) {
                    for (uint sellIdx = 0; volatileSellTokens.length > sellIdx; sellIdx++) {
                        if (sellWeights[sellIdx] > 0) {
                            address token = volatileSellTokens[sellIdx];
                            Price(price()).claimInsurance(token,
                                                          shortfall * sellWeights[sellIdx] / totalWeights);
                        }
                    }

                    for (uint buyIdx = 0; volatileBuyTokens.length > buyIdx; buyIdx++) {
                        if (buyWeights[buyIdx] > 0) {
                            address token = volatileBuyTokens[buyIdx];
                            Price(price()).claimInsurance(token, shortfall * buyWeights[buyIdx] / totalWeights);
                        }
                    }
                } else {
                    // TODO we have a problem and either there's a bug or margin callers didn't do their job
                    // we probably want to raise an event here, not an exception so as to not paralize margin calling
                }
            }

            deleteAccount(account);
        }
    }
}
