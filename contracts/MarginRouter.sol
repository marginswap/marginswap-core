// SPDX-License-Identifier: GPL-2.0-only
pragma solidity ^0.8.0;

import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import "../libraries/UniswapV2Library.sol";

import "./RoleAware.sol";
import "./Fund.sol";
import "./CrossMarginTrading.sol";
import "./Lending.sol";
import "./Admin.sol";
import "./IncentivizedHolder.sol";

// TODO get rid of enum
enum AMM {uni, sushi, compare, split}

contract MarginRouter is RoleAware, IncentivizedHolder {
    mapping(AMM => address) factories;
    address WETH;

    event CrossDeposit(
        address trader,
        address depositToken,
        uint256 depositAmount
    );
    event CrossTrade(
        address trader,
        address inToken,
        uint256 inTokenAmount,
        uint256 inTokenBorrow,
        address outToken,
        uint256 outTokenAmount,
        uint256 outTokenExtinguish
    );
    event CrossWithdraw(
        address trader,
        address withdrawToken,
        uint256 withdrawAmount
    );
    event CrossBorrow(
        address trader,
        address borrowToken,
        uint256 borrowAmount
    );

    modifier ensure(uint256 deadline) {
        require(deadline >= block.timestamp, "UniswapV2Router: EXPIRED");
        _;
    }

    constructor(
        address uniswapFactory,
        address sushiswapFactory,
        address _WETH,
        address _roles
    ) RoleAware(_roles) {
        factories[AMM.uni] = uniswapFactory;
        factories[AMM.sushi] = sushiswapFactory;
        WETH = _WETH;
    }

    function crossDeposit(address depositToken, uint256 depositAmount)
        external
    {
        require(
            Fund(fund()).depositFor(msg.sender, depositToken, depositAmount),
            "Cannot transfer deposit to margin account"
        );
        uint256 extinguishAmount =
            CrossMarginTrading(marginTrading()).registerDeposit(
                msg.sender,
                depositToken,
                depositAmount
            );
        if (extinguishAmount > 0) {
            Lending(lending()).payOff(depositToken, extinguishAmount);
            withdrawClaim(msg.sender, depositToken, extinguishAmount);
        }
        emit CrossDeposit(msg.sender, depositToken, depositAmount);
    }

    function crossDepositETH() external payable {
        Fund(fund()).depositToWETH{value: msg.value}();
        uint256 extinguishAmount =
            CrossMarginTrading(marginTrading()).registerDeposit(
                msg.sender,
                WETH,
                msg.value
            );
        if (extinguishAmount > 0) {
            Lending(lending()).payOff(WETH, extinguishAmount);
            withdrawClaim(msg.sender, WETH, extinguishAmount);
        }
        emit CrossDeposit(msg.sender, WETH, msg.value);
    }

    function crossWithdraw(address withdrawToken, uint256 withdrawAmount)
        external
    {
        CrossMarginTrading(marginTrading()).registerWithdrawal(
            msg.sender,
            withdrawToken,
            withdrawAmount
        );
        require(
            Fund(fund()).withdraw(withdrawToken, msg.sender, withdrawAmount),
            "Could not withdraw from fund"
        );
        emit CrossWithdraw(msg.sender, withdrawToken, withdrawAmount);
    }

    function crossWithdrawETH(uint256 withdrawAmount) external {
        CrossMarginTrading(marginTrading()).registerWithdrawal(
            msg.sender,
            WETH,
            withdrawAmount
        );
        Fund(fund()).withdrawETH(msg.sender, withdrawAmount);
    }

    function crossBorrow(address borrowToken, uint256 borrowAmount) external {
        Lending(lending()).registerBorrow(borrowToken, borrowAmount);
        CrossMarginTrading(marginTrading()).registerBorrow(
            msg.sender,
            borrowToken,
            borrowAmount
        );

        stakeClaim(msg.sender, borrowToken, borrowAmount);
        // TODO integrate into deposit
        emit CrossBorrow(msg.sender, borrowToken, borrowAmount);
    }

    // **** SWAP ****
    // requires the initial amount to have already been sent to the first pair
    function _swap(
        address factory,
        uint256[] memory amounts,
        address[] memory path,
        address _to
    ) internal virtual {
        for (uint256 i; i < path.length - 1; i++) {
            (address input, address output) = (path[i], path[i + 1]);
            (address token0, ) = UniswapV2Library.sortTokens(input, output);
            uint256 amountOut = amounts[i + 1];
            (uint256 amount0Out, uint256 amount1Out) =
                input == token0
                    ? (uint256(0), amountOut)
                    : (amountOut, uint256(0));
            address to =
                i < path.length - 2
                    ? UniswapV2Library.pairFor(factory, output, path[i + 2])
                    : _to;
            IUniswapV2Pair(UniswapV2Library.pairFor(factory, input, output))
                .swap(amount0Out, amount1Out, to, new bytes(0));
        }
    }

    function _swapExactT4T(
        address factory,
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path
    ) internal returns (uint256[] memory amounts) {
        amounts = UniswapV2Library.getAmountsOut(factory, amountIn, path);
        require(
            amounts[amounts.length - 1] >= amountOutMin,
            "MarginRouter: INSUFFICIENT_OUTPUT_AMOUNT"
        );
        require(
            Fund(fund()).withdraw(
                path[0],
                UniswapV2Library.pairFor(factory, path[0], path[1]),
                amounts[0]
            ),
            "MarginRouter: Insufficient lending funds"
        );
        _swap(factory, amounts, path, fund());
    }

    function authorizedSwapExactT4T(
        AMM amm,
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path
    ) external returns (uint256[] memory) {
        require(
            isAuthorizedFundTrader(msg.sender),
            "Calling contract is not authorized to trade with protocl funds"
        );
        return _swapExactT4T(factories[amm], amountIn, amountOutMin, path);
    }

    function _swapT4ExactT(
        address factory,
        uint256 amountOut,
        uint256 amountInMax,
        address[] calldata path
    ) internal returns (uint256[] memory amounts) {
        // TODO minimum trade?
        amounts = UniswapV2Library.getAmountsIn(factory, amountOut, path);
        require(
            amounts[0] <= amountInMax,
            "UniswapV2Router: EXCESSIVE_INPUT_AMOUNT"
        );
        require(
            Fund(fund()).withdraw(
                path[0],
                UniswapV2Library.pairFor(factory, path[0], path[1]),
                amounts[0]
            ),
            "MarginRouter: Insufficient lending funds"
        );
        _swap(factory, amounts, path, fund());
    }

    function authorizedSwapT4ExactT(
        AMM amm,
        uint256 amountOut,
        uint256 amountInMax,
        address[] calldata path
    ) external returns (uint256[] memory) {
        require(
            isAuthorizedFundTrader(msg.sender),
            "Calling contract is not authorized to trade with protocl funds"
        );
        return _swapT4ExactT(factories[amm], amountOut, amountInMax, path);
    }

    // deposit
    // borrow
    // auto-borrow for margin trades
    // auto-extinguish? yeah, why not

    // fees from fee controller / admin
    // clear trade w/ margintrading
    // make trade
    // register trade w/ margintrading (register within transaction)

    function crossSwapExactTokensForTokens(
        AMM amm,
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        uint256 deadline
    ) external ensure(deadline) returns (uint256[] memory amounts) {
        // calc fees
        uint256 fees =
            Admin(feeController()).subtractTradingFees(path[0], amountIn);

        // swap
        amounts = _swapExactT4T(
            factories[amm],
            amountIn - fees,
            amountOutMin,
            path
        );

        registerTrade(
            msg.sender,
            path[0],
            path[path.length - 1],
            amountIn,
            amounts[amounts.length - 1]
        );
    }

    function crossSwapTokensForExactTokens(
        AMM amm,
        uint256 amountOut,
        uint256 amountInMax,
        address[] calldata path,
        uint256 deadline
    ) external ensure(deadline) returns (uint256[] memory amounts) {
        // calc fees
        uint256 fees =
            Admin(feeController()).addTradingFees(
                path[path.length - 1],
                amountOut
            );

        // swap
        amounts = _swapT4ExactT(
            factories[amm],
            amountOut + fees,
            amountInMax,
            path
        );

        registerTrade(
            msg.sender,
            path[0],
            path[path.length - 1],
            amounts[0],
            amountOut
        );
    }

    function registerTrade(
        address trader,
        address inToken,
        address outToken,
        uint256 inAmount,
        uint256 outAmount
    ) internal {
        (uint256 extinguishAmount, uint256 borrowAmount) =
            CrossMarginTrading(marginTrading()).registerTradeAndBorrow(
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
            Lending(lending()).registerBorrow(outToken, borrowAmount);
            stakeClaim(trader, inToken, borrowAmount);
        }

        emit CrossTrade(
            trader,
            inToken,
            inAmount,
            borrowAmount,
            outToken,
            outAmount,
            extinguishAmount
        );
    }

    function getAmountsOut(
        AMM amm,
        uint256 inAmount,
        address[] calldata path
    ) external view returns (uint256[] memory) {
        address factory = factories[amm];
        return UniswapV2Library.getAmountsOut(factory, inAmount, path);
    }

    function getAmountsIn(
        AMM amm,
        uint256 outAmount,
        address[] calldata path
    ) external view returns (uint256[] memory) {
        address factory = factories[amm];
        return UniswapV2Library.getAmountsIn(factory, outAmount, path);
    }
}
