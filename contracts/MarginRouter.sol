// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";

import "./RoleAware.sol";
import "../interfaces/IMarginTrading.sol";
import "./Lending.sol";
import "./Admin.sol";
import "./IncentivizedHolder.sol";
import "./BaseRouter.sol";

/// @title Top level transaction controller
contract MarginRouter is RoleAware, IncentivizedHolder, BaseRouter {
    event AccountUpdated(address indexed trader);

    uint256 public constant mswapFeesPer10k = 10;
    address public immutable WETH;

    constructor(address _WETH, address _roles) RoleAware(_roles) {
        WETH = _WETH;
    }

    ///////////////////////////
    // Cross margin endpoints
    ///////////////////////////

    /// @notice traders call this to deposit funds on cross margin
    function crossDeposit(address depositToken, uint256 depositAmount)
        external
    {
        Fund(fund()).depositFor(msg.sender, depositToken, depositAmount);

        uint256 extinguishAmount =
            IMarginTrading(crossMarginTrading()).registerDeposit(
                msg.sender,
                depositToken,
                depositAmount
            );
        if (extinguishAmount > 0) {
            Lending(lending()).payOff(depositToken, extinguishAmount);
            withdrawClaim(msg.sender, depositToken, extinguishAmount);
        }
        emit AccountUpdated(msg.sender);
    }

    /// @notice deposit wrapped ehtereum into cross margin account
    function crossDepositETH() external payable {
        Fund(fund()).depositToWETH{value: msg.value}();
        uint256 extinguishAmount =
            IMarginTrading(crossMarginTrading()).registerDeposit(
                msg.sender,
                WETH,
                msg.value
            );
        if (extinguishAmount > 0) {
            Lending(lending()).payOff(WETH, extinguishAmount);
            withdrawClaim(msg.sender, WETH, extinguishAmount);
        }
        emit AccountUpdated(msg.sender);
    }

    /// @notice withdraw deposits/earnings from cross margin account
    function crossWithdraw(address withdrawToken, uint256 withdrawAmount)
        external
    {
        IMarginTrading(crossMarginTrading()).registerWithdrawal(
            msg.sender,
            withdrawToken,
            withdrawAmount
        );
        Fund(fund()).withdraw(withdrawToken, msg.sender, withdrawAmount);
        emit AccountUpdated(msg.sender);
    }

    /// @notice withdraw ethereum from cross margin account
    function crossWithdrawETH(uint256 withdrawAmount) external {
        IMarginTrading(crossMarginTrading()).registerWithdrawal(
            msg.sender,
            WETH,
            withdrawAmount
        );
        Fund(fund()).withdrawETH(msg.sender, withdrawAmount);
        emit AccountUpdated(msg.sender);
    }

    /// @notice borrow into cross margin trading account
    function crossBorrow(address borrowToken, uint256 borrowAmount) external {
        Lending(lending()).registerBorrow(borrowToken, borrowAmount);
        IMarginTrading(crossMarginTrading()).registerBorrow(
            msg.sender,
            borrowToken,
            borrowAmount
        );

        stakeClaim(msg.sender, borrowToken, borrowAmount);
        emit AccountUpdated(msg.sender);
    }

    /// @notice convenience function to perform overcollateralized borrowing
    /// against a cross margin account.
    /// @dev caution: the account still has to have a positive balaance at the end
    /// of the withdraw. So an underwater account may not be able to withdraw
    function crossOvercollateralizedBorrow(
        address depositToken,
        uint256 depositAmount,
        address borrowToken,
        uint256 withdrawAmount
    ) external {
        Fund(fund()).depositFor(msg.sender, depositToken, depositAmount);

        Lending(lending()).registerBorrow(borrowToken, withdrawAmount);
        IMarginTrading(crossMarginTrading()).registerOvercollateralizedBorrow(
            msg.sender,
            depositToken,
            depositAmount,
            borrowToken,
            withdrawAmount
        );

        Fund(fund()).withdraw(borrowToken, msg.sender, withdrawAmount);
        stakeClaim(msg.sender, borrowToken, withdrawAmount);
        emit AccountUpdated(msg.sender);
    }

    /// @notice close an account that is no longer borrowing and return gains
    function crossCloseAccount() external {
        (address[] memory holdingTokens, uint256[] memory holdingAmounts) =
            IMarginTrading(crossMarginTrading()).getHoldingAmounts(msg.sender);

        // requires all debts paid off
        IMarginTrading(crossMarginTrading()).registerLiquidation(msg.sender);

        for (uint256 i; holdingTokens.length > i; i++) {
            Fund(fund()).withdraw(
                holdingTokens[i],
                msg.sender,
                holdingAmounts[i]
            );
        }

        emit AccountUpdated(msg.sender);
    }

    /// @notice entry point for swapping tokens held in cross margin account
    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        bytes32 amms,
        address[] calldata tokens,
        uint256 deadline
    ) external ensure(deadline) returns (uint256[] memory amounts) {
        // calc fees
        uint256 fees = takeFeesFromInput(amountIn);

        address[] memory pairs;
        (amounts, pairs) = UniswapStyleLib.getAmountsOut(
            amountIn - fees,
            amms,
            tokens
        );

        // checks that trader is within allowed lending bounds
        registerTrade(
            msg.sender,
            tokens[0],
            tokens[tokens.length - 1],
            amountIn,
            amounts[amounts.length - 1]
        );

        _fundSwapExactT4T(amounts, amountOutMin, pairs, tokens);
    }

    /// @notice entry point for swapping tokens held in cross margin account
    function swapTokensForExactTokens(
        uint256 amountOut,
        uint256 amountInMax,
        bytes32 amms,
        address[] calldata tokens,
        uint256 deadline
    ) external ensure(deadline) returns (uint256[] memory amounts) {
        address[] memory pairs;
        (amounts, pairs) = UniswapStyleLib.getAmountsIn(
            amountOut + takeFeesFromOutput(amountOut),
            amms,
            tokens
        );

        // checks that trader is within allowed lending bounds
        registerTrade(
            msg.sender,
            tokens[0],
            tokens[tokens.length - 1],
            amounts[0],
            amountOut
        );

        _fundSwapT4ExactT(amounts, amountInMax, pairs, tokens);
    }

    /// @dev helper function does all the work of telling other contracts
    /// about a cross margin trade
    function registerTrade(
        address trader,
        address inToken,
        address outToken,
        uint256 inAmount,
        uint256 outAmount
    ) internal {
        (uint256 extinguishAmount, uint256 borrowAmount) =
            IMarginTrading(crossMarginTrading()).registerTradeAndBorrow(
                trader,
                inToken,
                outToken,
                inAmount,
                outAmount
            );
        if (extinguishAmount > 0) {
            Lending(lending()).payOff(outToken, extinguishAmount);
            withdrawClaim(trader, outToken, extinguishAmount);
        }
        if (borrowAmount > 0) {
            Lending(lending()).registerBorrow(inToken, borrowAmount);
            stakeClaim(trader, inToken, borrowAmount);
        }

        emit AccountUpdated(trader);
    }

    /////////////
    // Helpers
    /////////////

    /// @dev internal helper swapping exact token for token on AMM
    function _fundSwapExactT4T(
        uint256[] memory amounts,
        uint256 amountOutMin,
        address[] memory pairs,
        address[] calldata tokens
    ) internal {
        require(
            amounts[amounts.length - 1] >= amountOutMin,
            "MarginRouter: INSUFFICIENT_OUTPUT_AMOUNT"
        );
        Fund(fund()).withdraw(tokens[0], pairs[0], amounts[0]);
        _swap(amounts, pairs, tokens, fund());
    }

    /// @notice make swaps on AMM using protocol funds, only for authorized contracts
    function authorizedSwapExactT4T(
        uint256 amountIn,
        uint256 amountOutMin,
        bytes32 amms,
        address[] calldata tokens
    ) external returns (uint256[] memory amounts) {
        require(
            isAuthorizedFundTrader(msg.sender),
            "Calling contract is not authorized to trade with protocl funds"
        );
        address[] memory pairs;
        (amounts, pairs) = UniswapStyleLib.getAmountsOut(
            amountIn,
            amms,
            tokens
        );
        _fundSwapExactT4T(amounts, amountOutMin, pairs, tokens);
    }

    // @dev internal helper swapping exact token for token on on AMM
    function _fundSwapT4ExactT(
        uint256[] memory amounts,
        uint256 amountInMax,
        address[] memory pairs,
        address[] calldata tokens
    ) internal {
        require(
            amounts[0] <= amountInMax,
            "MarginRouter: EXCESSIVE_INPUT_AMOUNT"
        );
        Fund(fund()).withdraw(tokens[0], pairs[0], amounts[0]);
        _swap(amounts, pairs, tokens, fund());
    }

    //// @notice swap protocol funds on AMM, only for authorized
    function authorizedSwapT4ExactT(
        uint256 amountOut,
        uint256 amountInMax,
        bytes32 amms,
        address[] calldata tokens
    ) external returns (uint256[] memory amounts) {
        require(
            isAuthorizedFundTrader(msg.sender),
            "Calling contract is not authorized to trade with protocl funds"
        );

        address[] memory pairs;
        (amounts, pairs) = UniswapStyleLib.getAmountsIn(
            amountOut,
            amms,
            tokens
        );
        _fundSwapT4ExactT(amounts, amountInMax, pairs, tokens);
    }

    function takeFeesFromOutput(uint256 amount)
        internal
        pure
        returns (uint256 fees)
    {
        fees = (mswapFeesPer10k * amount) / 10_000;
    }

    function takeFeesFromInput(uint256 amount)
        internal
        pure
        returns (uint256 fees)
    {
        fees = (mswapFeesPer10k * amount) / (10_000 + mswapFeesPer10k);
    }

    function getAmountsOut(
        uint256 inAmount,
        bytes32 amms,
        address[] calldata tokens
    ) external view returns (uint256[] memory amounts) {
        (amounts, ) = UniswapStyleLib.getAmountsOut(inAmount, amms, tokens);
    }

    function getAmountsIn(
        uint256 outAmount,
        bytes32 amms,
        address[] calldata tokens
    ) external view returns (uint256[] memory amounts) {
        (amounts, ) = UniswapStyleLib.getAmountsIn(outAmount, amms, tokens);
    }
}
