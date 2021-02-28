import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import "../libraries/UniswapV2Library.sol";

import "./RoleAware.sol";
import "./Fund.sol";
import "./CrossMarginTrading.sol";
import "./Lending.sol";
import "./Admin.sol";

enum AMM {uni, sushi, compare, split}

contract MarginRouter is RoleAware {
    mapping(AMM => address) factories;
    address WETH;

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
        noIntermediary
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
            CrossMarginTrading(marginTrading()).registerPayOff(
                msg.sender,
                depositToken,
                extinguishAmount
            );
            Lending(lending()).payOff(depositToken, extinguishAmount);
        }
    }

    function crossDepositETH() external payable noIntermediary {
        Fund(fund()).depositToWETH{value: msg.value}();
        uint256 extinguishAmount =
            CrossMarginTrading(marginTrading()).registerDeposit(
                msg.sender,
                WETH,
                msg.value
            );
        if (extinguishAmount > 0) {
            CrossMarginTrading(marginTrading()).registerPayOff(
                msg.sender,
                WETH,
                extinguishAmount
            );
            Lending(lending()).payOff(WETH, extinguishAmount);
        }
    }

    function crossWithdraw(address withdrawToken, uint256 withdrawAmount)
        external
        noIntermediary
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
    }

    function crossWithdrawETH(uint256 withdrawAmount) external noIntermediary {
        CrossMarginTrading(marginTrading()).registerWithdrawal(
            msg.sender,
            WETH,
            withdrawAmount
        );
        Fund(fund()).withdrawETH(msg.sender, withdrawAmount);
    }

    function crossBorrow(address borrowToken, uint256 borrowAmount)
        external
        noIntermediary
    {
        Lending(lending()).registerBorrow(borrowToken, borrowAmount);
        CrossMarginTrading(marginTrading()).registerBorrow(
            msg.sender,
            borrowToken,
            borrowAmount
        );
    }

    function crossExtinguishDebt(address debtToken, uint256 extinguishAmount)
        external
        noIntermediary
    {
        CrossMarginTrading(marginTrading()).registerPayOff(
            msg.sender,
            debtToken,
            extinguishAmount
        );
        Lending(lending()).payOff(debtToken, extinguishAmount);
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
        address[] calldata path,
        uint256 deadline
    ) internal returns (uint256[] memory amounts) {
        amounts = UniswapV2Library.getAmountsOut(factory, amountIn, path);
        require(
            amounts[amounts.length - 1] >= amountOutMin,
            "MarginRouter: INSUFFICIENT_OUTPUT_AMOUNT"
        );
        require(
            Fund(fund()).sendTokenTo(
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
        require(isAuthorizedFundTrader(msg.sender),
                "Calling contract is not authorized to trade with protocl funds");
        return _swapExactT4T(factories[amm],
                             amountIn,
                             amountOutMin,
                             path,
                             block.timestamp + 1);
    }

    function _swapT4ExactT(
        address factory,
        uint256 amountOut,
        uint256 amountInMax,
        address[] calldata path,
        uint256 deadline
    ) internal returns (uint256[] memory amounts) {
        // TODO minimum trade?
        amounts = UniswapV2Library.getAmountsIn(factory, amountOut, path);
        require(
            amounts[0] <= amountInMax,
            "UniswapV2Router: EXCESSIVE_INPUT_AMOUNT"
        );
        require(
            Fund(fund()).sendTokenTo(
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
        require(isAuthorizedFundTrader(msg.sender),
                "Calling contract is not authorized to trade with protocl funds");
        return _swapT4ExactT(factories[amm],
                             amountOut,
                             amountInMax,
                             path,
                             block.timestamp + 1);
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
    ) external noIntermediary returns (uint256[] memory amounts) {
        // calc fees
        uint256 fees =
            Admin(feeController()).subtractTradingFees(path[0], amountIn);

        // swap
        address factory = factories[amm];
        amounts = _swapExactT4T(
            factory,
            amountIn - fees,
            amountOutMin,
            path,
            deadline
        );

        address outToken = path[path.length - 1];
        // register the trade
        uint256 borrowAmount =
            CrossMarginTrading(marginTrading()).registerTradeAndBorrow(
                msg.sender,
                path[0],
                outToken,
                amountIn,
                amounts[amounts.length - 1]
            );
        Lending(lending()).registerBorrow(outToken, borrowAmount);
    }

    function crossSwapTokensForExactTokens(
        AMM amm,
        uint256 amountOut,
        uint256 amountInMax,
        address[] calldata path,
        uint256 deadline
    ) external noIntermediary returns (uint256[] memory amounts) {
        // calc fees
        uint256 fees =
            Admin(feeController()).addTradingFees(
                path[path.length - 1],
                amountOut
            );

        // swap
        address factory = factories[amm];
        amounts = _swapT4ExactT(
            factory,
            amountOut + fees,
            amountInMax,
            path,
            deadline
        );

        address outToken = path[path.length - 1];
        // register the trade
        uint256 borrowAmount =
            CrossMarginTrading(marginTrading()).registerTradeAndBorrow(
                msg.sender,
                path[0],
                outToken,
                amounts[0],
                amountOut
            );
        Lending(lending()).registerBorrow(outToken, borrowAmount);
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

// TODO use cached prices or borrow and write prices before registering trade
