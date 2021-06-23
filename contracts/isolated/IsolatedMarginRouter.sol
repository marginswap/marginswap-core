import "../RoleAware.sol";

import "../Lending.sol";

import "../BaseRouter.sol";
import "../../libraries/IncentiveReporter.sol";

import "./IsolatedMarginTrading.sol";

contract IsolatedMarginRouter is RoleAware, BaseRouter {
    event IsolatedAccountUpdated(address indexed trader, address isolatedPair);
    event IsolatedMarginTrade(
        address indexed trader,
        address fromToken,
        address toToken,
        uint256 fromAmount,
        uint256 toAmount
    );

    uint256 public constant mswapFeesPer10k = 10;
    address public immutable WETH;

    constructor(
        address _WETH,
        address _amm1Factory,
        address _amm2Factory,
        address _amm3Factory,
        bytes32 _amm1InitHash,
        bytes32 _amm2InitHash,
        bytes32 _amm3InitHash,
        address _roles
    )
        UniswapStyleLib(
            _amm1Factory,
            _amm2Factory,
            _amm3Factory,
            _amm1InitHash,
            _amm2InitHash,
            _amm3InitHash
        )
        RoleAware(_roles)
    {
        WETH = _WETH;
    }

    /// @notice entry point for swapping tokens into isolated pair
    function swapExactTokensForTokensPosition(
        uint256 amountIn,
        uint256 amountOutMin,
        bytes32 amms,
        address[] calldata tokens,
        address _isolatedPair,
        uint256 depositFrom,
        uint256 depositTo,
        uint256 deadline
    ) external ensure(deadline) returns (uint256[] memory amounts) {
        require(
            tokens[0] == IsolatedMarginTrading(_isolatedPair).borrowToken() &&
                tokens[tokens.length - 1] ==
                IsolatedMarginTrading(_isolatedPair).holdingToken(),
            "Path does not match isolated pair"
        );

        // calc fees
        uint256 fees = takeFeesFromInput(amountIn);

        address[] memory pairs;
        (amounts, pairs) = UniswapStyleLib._getAmountsOut(
            amountIn - fees,
            amms,
            tokens
        );

        getDeposits(
            msg.sender,
            tokens[0],
            tokens[tokens.length - 1],
            depositFrom,
            depositTo
        );

        // checks that trader is within allowed lending bounds
        registerPosition(
            msg.sender,
            IsolatedMarginTrading(_isolatedPair),
            amountIn,
            amounts[amounts.length - 1],
            depositFrom,
            depositTo
        );

        _fundSwapExactT4T(amounts, amountOutMin, pairs, tokens);
        emit IsolatedAccountUpdated(msg.sender, _isolatedPair);
        emit IsolatedMarginTrade(
            msg.sender,
            tokens[0],
            tokens[tokens.length - 1],
            amounts[0],
            amounts[amounts.length - 1]
        );
    }

    /// @notice entry point for swapping tokens into isolated pair
    function swapTokensForExactTokensPosition(
        uint256 amountOut,
        uint256 amountInMax,
        bytes32 amms,
        address[] calldata tokens,
        address _isolatedPair,
        uint256 depositFrom,
        uint256 depositTo,
        uint256 deadline
    ) external ensure(deadline) returns (uint256[] memory amounts) {
        require(
            tokens[0] == IsolatedMarginTrading(_isolatedPair).borrowToken() &&
                tokens[tokens.length - 1] ==
                IsolatedMarginTrading(_isolatedPair).holdingToken(),
            "Path does not match isolated pair"
        );
        address[] memory pairs;
        (amounts, pairs) = UniswapStyleLib._getAmountsIn(
            amountOut + takeFeesFromOutput(amountOut),
            amms,
            tokens
        );

        getDeposits(
            msg.sender,
            tokens[0],
            tokens[tokens.length - 1],
            depositFrom,
            depositTo
        );

        // checks that trader is within allowed lending bounds
        registerPosition(
            msg.sender,
            IsolatedMarginTrading(_isolatedPair),
            amounts[0],
            amountOut,
            depositFrom,
            depositTo
        );

        _fundSwapT4ExactT(amounts, amountInMax, pairs, tokens);
        emit IsolatedAccountUpdated(msg.sender, _isolatedPair);
        emit IsolatedMarginTrade(
            msg.sender,
            tokens[0],
            tokens[tokens.length - 1],
            amounts[0],
            amounts[amounts.length - 1]
        );
    }

    /// @notice entry point for swapping tokens out of isolated pair
    function swapExactTokensForTokensUnwind(
        uint256 amountIn,
        uint256 amountOutMin,
        bytes32 amms,
        address[] calldata tokens,
        address _isolatedPair,
        uint256 withdrawFrom,
        uint256 withdrawTo,
        uint256 deadline
    ) external ensure(deadline) returns (uint256[] memory amounts) {
        require(
            tokens[tokens.length - 1] ==
                IsolatedMarginTrading(_isolatedPair).borrowToken() &&
                tokens[0] ==
                IsolatedMarginTrading(_isolatedPair).holdingToken(),
            "Path does not match isolated pair"
        );

        // calc fees
        uint256 fees = takeFeesFromInput(amountIn);

        address[] memory pairs;
        (amounts, pairs) = UniswapStyleLib._getAmountsOut(
            amountIn - fees,
            amms,
            tokens
        );

        // checks that trader is within allowed lending bounds
        registerUnwind(
            msg.sender,
            IsolatedMarginTrading(_isolatedPair),
            amountIn,
            amounts[amounts.length - 1],
            withdrawFrom,
            withdrawTo
        );

        getWithdrawals(
            msg.sender,
            tokens[0],
            tokens[tokens.length - 1],
            withdrawFrom,
            withdrawTo
        );

        _fundSwapExactT4T(amounts, amountOutMin, pairs, tokens);
        emit IsolatedAccountUpdated(msg.sender, _isolatedPair);
        emit IsolatedMarginTrade(
            msg.sender,
            tokens[0],
            tokens[tokens.length - 1],
            amounts[0],
            amounts[amounts.length - 1]
        );
    }

    /// @notice entry point for swapping tokens out of isolated pair
    function swapTokensForExactTokensUnwind(
        uint256 amountOut,
        uint256 amountInMax,
        bytes32 amms,
        address[] calldata tokens,
        address _isolatedPair,
        uint256 withdrawFrom,
        uint256 withdrawTo,
        uint256 deadline
    ) external ensure(deadline) returns (uint256[] memory amounts) {
        require(
            tokens[tokens.length - 1] ==
                IsolatedMarginTrading(_isolatedPair).borrowToken() &&
                tokens[0] ==
                IsolatedMarginTrading(_isolatedPair).holdingToken(),
            "Path does not match isolated pair"
        );
        address[] memory pairs;
        (amounts, pairs) = UniswapStyleLib._getAmountsIn(
            amountOut + takeFeesFromOutput(amountOut),
            amms,
            tokens
        );

        // checks that trader is within allowed lending bounds
        registerUnwind(
            msg.sender,
            IsolatedMarginTrading(_isolatedPair),
            amounts[0],
            amountOut,
            withdrawFrom,
            withdrawTo
        );

        getWithdrawals(
            msg.sender,
            tokens[0],
            tokens[tokens.length - 1],
            withdrawFrom,
            withdrawTo
        );

        _fundSwapT4ExactT(amounts, amountInMax, pairs, tokens);
        emit IsolatedAccountUpdated(msg.sender, _isolatedPair);
        emit IsolatedMarginTrade(
            msg.sender,
            tokens[0],
            tokens[tokens.length - 1],
            amounts[0],
            amounts[amounts.length - 1]
        );
    }

    function registerPosition(
        address trader,
        IsolatedMarginTrading isolatedPair,
        uint256 inAmount,
        uint256 outAmount,
        uint256 depositFrom,
        uint256 depositTo
    ) internal {
        uint256 borrowAmount = inAmount - depositFrom;

        isolatedPair.registerPosition(
            trader,
            borrowAmount,
            outAmount + depositTo,
            depositFrom > 0 || depositTo > 0
        );

        Lending(lending()).registerBorrow(address(isolatedPair), borrowAmount);
        Lending(lending()).updateHourlyYield(address(isolatedPair));
    }

    function registerUnwind(
        address trader,
        IsolatedMarginTrading isolatedPair,
        uint256 inAmount,
        uint256 outAmount,
        uint256 withdrawFrom,
        uint256 withdrawTo
    ) internal {
        uint256 extinguishAmount = outAmount - withdrawTo;

        isolatedPair.registerUnwind(
            trader,
            extinguishAmount,
            inAmount - withdrawFrom
        );

        Lending(lending()).payOff(address(isolatedPair), extinguishAmount);
        Lending(lending()).updateHourlyYield(address(isolatedPair));
    }

    function getDeposits(
        address trader,
        address fromToken,
        address toToken,
        uint256 depositFrom,
        uint256 depositTo
    ) internal {
        if (depositFrom > 0) {
            Fund(fund()).depositFor(trader, fromToken, depositFrom);
        }

        if (depositTo > 0) {
            Fund(fund()).depositFor(trader, toToken, depositTo);
        }
    }

    function getWithdrawals(
        address trader,
        address fromToken,
        address toToken,
        uint256 withdrawalFrom,
        uint256 withdrawalTo
    ) internal {
        if (withdrawalFrom > 0) {
            Fund(fund()).withdraw(fromToken, trader, withdrawalFrom);
        }
        if (withdrawalTo > 0) {
            Fund(fund()).withdraw(toToken, trader, withdrawalTo);
        }
    }

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
}
