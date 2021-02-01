pragma solidity ^0.7.0;

import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/math/SafeMath.sol';
import './Fund.sol';
import './Lending.sol';
import './RoleAware.sol';
import './MarginRouter.sol';

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
    address WETH;

    constructor(address _WETH, address _roles) RoleAware(_roles) Ownable() {
        WETH = _WETH;
        liquidationThresholdPercent = 20;
    }

    function setLeverage(uint _leverage) external onlyOwner {
        leverage = _leverage;
    }

    function setLiquidationThresholdPercent(uint threshold) external onlyOwner {
        liquidationThresholdPercent = threshold;
    }

    function deposit(address depositToken, uint depositAmount) external {
        require(Fund(fund()).activeTokens(depositToken),
                "Not an approved token");
        require(IERC20(depositToken).transferFrom(msg.sender,
                                                  fund(),
                                                  depositAmount),
                "Cannot transfer deposit to margin account");
        addHolding(marginAccounts[msg.sender], depositToken, depositAmount);
    }

    function depositETH() external payable {
        Fund(fund()).depositToWETH{value: msg.value}();
        addHolding(marginAccounts[msg.sender], WETH, msg.value);
    }

    function addHolding(MarginAccount storage account, address token, uint depositAmount) internal {
        if (!hasHoldingToken(account, token)) {
            account.holdingTokens.push(token);
        }

        account.holdings[token] += depositAmount;
    }
    
    function borrow(address borrowToken, uint borrowAmount) external {
        MarginAccount storage account = marginAccounts[msg.sender];

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

    function withdraw(address withdrawToken, uint withdrawAmount) external {
        MarginAccount storage account = marginAccounts[msg.sender];

        // SafeMath throws on underflow 
        account.holdings[withdrawToken] -= withdrawAmount;
        require(positiveBalance(account),
                "Account balance is too low to withdraw");
        require(Fund(fund()).withdraw(withdrawToken, msg.sender, withdrawAmount),
                "Could not withdraw from fund");
    }

    function positiveBalance(MarginAccount storage account) internal returns (bool) {
        uint loan = loanInETH(account);
        uint holdings = holdingsInETH(account);
        // The following condition should hold:
        // holdings / loan >= (leverage + 1) / leverage
        // =>
        return holdings * (leverage + 1) >= loan * leverage;
    }

    function extinguishDebt(address debtToken, uint extinguishAmount) external {
        MarginAccount storage account = marginAccounts[msg.sender];
        // SafeMath will throw if insufficient funds
        account.borrowed[debtToken] = Lending(lending())
            .applyBorrowInterest(account.borrowed[debtToken],
                                 debtToken,
                                 account.borrowedYieldQuotientsFP[debtToken]);
        account.borrowed[debtToken] -= extinguishAmount;
        account.holdings[debtToken] -= extinguishAmount;
        Lending(lending()).payOff(debtToken, extinguishAmount);
    }

    function hasHoldingToken(MarginAccount storage account, address token) internal view returns (bool) {
        return account.holdsToken[token];
    }

    function hasBorrowedToken(MarginAccount storage account, address token) internal view returns (bool) {
        return account.borrowedYieldQuotientsFP[token] > 0;
    }
    
    function loanInETH(MarginAccount storage account) internal returns (uint) {
        return sumTokensInETHWithYield(account.borrowTokens,
                                       account.borrowed,
                                       account.borrowedYieldQuotientsFP);
    }

    function holdingsInETH(MarginAccount storage account) internal view returns (uint) {
        return sumTokensInETH(account.holdingTokens, account.holdings);
    }

    function marginCallable(MarginAccount storage account) internal returns (bool) {
        uint loan = loanInETH(account);
        uint holdings = holdingsInETH(account);
        // The following should hold:
        // holdings / loan >= (leverage + liquidationThresholdPercent / 100) / leverage
        // =>
        return holdings * leverage * 100 >= (100 * leverage + liquidationThresholdPercent) * loan;
    }

    function canSell(MarginAccount storage account, address token, uint amount)
        internal view returns (bool) {
        return account.holdings[token] >= amount;
    }

    function sellPath(address sourceToken, address targetToken)
        internal view returns (address[] memory) {
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

    function spotConversionAmount(address inToken, address outToken, uint inAmount)
        internal returns (uint) {
        address[] memory path = sellPath(inToken, outToken);
        uint[] memory pathAmounts = MarginRouter(router()).getAmountsOut(inAmount, path);
        return pathAmounts[pathAmounts.length - 1];
    }

    function ethSpotPrice(address token, uint amount)
        internal view returns (uint) {
        if (token == WETH) {
            return 1;
        } else {
            address[] memory path = new address[](2);
            path[0] = token;
            path[1] = WETH;
            uint[] memory pathAmounts = MarginRouter(router()).getAmountsOut(amount, path);
            return pathAmounts[pathAmounts.length - 1];
        }
    }

    function sumTokensInETH(address[] storage tokens, mapping(address => uint) storage amounts)
        internal view returns (uint totalETH) {
        for (uint tokenId = 0; tokenId < tokens.length; tokenId++) {
            address token = tokens[tokenId];
            totalETH += ethSpotPrice(token, amounts[token]);
        }
    }
    
    function sumTokensInETHWithYield(address[] storage tokens,
                                     mapping(address => uint) storage amounts,
                                     mapping(address => uint) storage yieldQuotientsFP)
        internal returns (uint totalETH) {
        for (uint tokenId = 0; tokenId < tokens.length; tokenId++) {
            address token = tokens[tokenId];
            uint yield = Lending(lending()).viewBorrowingYield(token);
            // 1 * FP / FP = 1
            uint amountInToken = (amounts[token] * yield) / yieldQuotientsFP[token];
            totalETH += ethSpotPrice(token, amountInToken);
        }
    }

    function adjustAmounts(MarginAccount storage account,
                           address[] memory path,
                           uint[] memory amounts) internal {
        uint soldAmount = amounts[0];
        uint boughtAmount = amounts[amounts.length - 1];

        account.holdings[path[0]] -= soldAmount;
        address targetToken = path[path.length - 1];
        addHolding(account, targetToken, boughtAmount);
    }

    function swapExactTokensForTokens(uint amountIn,
                                      uint amountOutMin,
                                      address[] calldata path,
                                      uint deadline)
        external returns (uint[] memory amounts) {
        MarginAccount storage account = marginAccounts[msg.sender];
        address startingToken = path[0];
        require(canSell(account, startingToken, amountIn));
        amounts = MarginRouter(router()).swapExactTokensForTokens(amountIn,
                                                                  amountOutMin,
                                                                  path,
                                                                  deadline);
        adjustAmounts(account, path, amounts);
        return amounts;
    }

    function swapTokensForExactTokens(uint amountOut,
                                      uint amountInMax,
                                      address[] calldata path,
                                      uint deadline)
        external returns (uint[] memory amounts) {
        MarginAccount storage account = marginAccounts[msg.sender];
        address startingToken = path[0];
        require(canSell(account, startingToken, amountInMax));
        amounts = MarginRouter(router()).swapTokensForExactTokens(amountOut,
                                                                  amountInMax,
                                                                  path,
                                                                  deadline);
        adjustAmounts(account, path, amounts);
        return amounts;
    }
}
