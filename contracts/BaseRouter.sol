// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "./Fund.sol";
import "../libraries/UniswapStyleLib.sol";

abstract contract BaseRouter {
    /// @notice wrapped ETH ERC20 contract

    modifier ensure(uint256 deadline) {
        require(deadline >= block.timestamp, "Trade has expired");
        _;
    }

    // **** SWAP ****
    /// @dev requires the initial amount to have already been sent to the first pair
    function _swap(
        uint256[] memory amounts,
        address[] memory pairs,
        address[] memory tokens,
        address _to
    ) internal {
        address outToken = tokens[tokens.length - 1];
        uint256 startingBalance = IERC20(outToken).balanceOf(_to);
        for (uint256 i; i < pairs.length; i++) {
            (address input, address output) = (tokens[i], tokens[i + 1]);
            (address token0, ) = UniswapStyleLib.sortTokens(input, output);

            uint256 amountOut = amounts[i + 1];

            (uint256 amount0Out, uint256 amount1Out) =
                input == token0
                    ? (uint256(0), amountOut)
                    : (amountOut, uint256(0));

            address to = i < pairs.length - 1 ? pairs[i + 1] : _to;
            IUniswapV2Pair pair = IUniswapV2Pair(pairs[i]);
            pair.swap(amount0Out, amount1Out, to, new bytes(0));
        }

        uint256 endingBalance = IERC20(outToken).balanceOf(_to);
        require(
            endingBalance >= startingBalance + amounts[amounts.length - 1],
            "Defective AMM route; balances don't match"
        );
    }
}
