// SPDX-License-Identifier: GPL-2.0-only
pragma solidity ^0.8.0;

import "./RoleAware.sol";
import "./MarginRouter.sol";

// Token price with rolling window
struct TokenPrice {
    uint256 blockLastUpdated;
    uint256[] tokenPer1kHistory;
    uint256 currentPriceIndex;
    address[] liquidationPath;
    address[] inverseLiquidationPath;
}

abstract contract PriceAware is Ownable, RoleAware {
    address public constant UNI = 0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f;
    address public peg;
    mapping(address => TokenPrice) tokenPrices;
    uint256 constant PRICE_HIST_LENGTH = 30;

    constructor(address _peg) Ownable() {
        peg = _peg;
    }

    function getCurrentPriceInPeg(address token, uint256 inAmount)
        internal
        view
        returns (uint256)
    {
        TokenPrice storage tokenPrice = tokenPrices[token];
        require(
            tokenPrice.liquidationPath.length > 1,
            "Token does not have a liquidation path"
        );
        return
            (inAmount * 1000 ether) /
            tokenPrice.tokenPer1kHistory[tokenPrice.currentPriceIndex];
    }

    function getUpdatedPriceInPeg(address token, uint256 inAmount)
        internal
        returns (uint256)
    {
        if (token == peg) {
            return inAmount;
        } else {
            TokenPrice storage tokenPrice = tokenPrices[token];
            require(
                tokenPrice.liquidationPath.length > 1,
                "Token does not have a liquidation path"
            );
            uint256[] memory pathAmounts =
                MarginRouter(router()).getAmountsOut(
                    UNI,
                    inAmount,
                    tokenPrice.liquidationPath
                );
            uint256 outAmount = pathAmounts[pathAmounts.length - 1];
            tokenPrice.currentPriceIndex =
                (tokenPrice.currentPriceIndex + 1) %
                tokenPrice.tokenPer1kHistory.length;
            tokenPrice.tokenPer1kHistory[tokenPrice.currentPriceIndex] =
                (1000 ether * inAmount) /
                outAmount;
            return outAmount;
        }
    }

    // TODO rename to amounts in / out
    function getCostInPeg(address token, uint256 outAmount)
        internal
        view
        returns (uint256)
    {
        if (token == peg) {
            return outAmount;
        } else {
            TokenPrice storage tokenPrice = tokenPrices[token];
            require(
                tokenPrice.inverseLiquidationPath.length > 1,
                "Token does not have a liquidation path"
            );

            uint256[] memory pathAmounts =
                MarginRouter(router()).getAmountsIn(
                    UNI,
                    outAmount,
                    tokenPrice.inverseLiquidationPath
                );
            uint256 inAmount = pathAmounts[0];
            return inAmount;
        }
    }

    // add path from token to current liquidation peg (i.e. USDC)
    function setLiquidationPath(address[] memory path) external onlyOwner {
        // TODO
        // make sure paths aren't excessively long
        // add the inverse as well
    }

    function liquidateToPeg(address token, uint256 amount)
        internal
        returns (uint256)
    {
        if (token == peg) {
            return amount;
        } else {
            TokenPrice memory tP = tokenPrices[token];
            uint256[] memory amounts =
                MarginRouter(router()).authorizedSwapExactT4T(
                    UNI,
                    amount,
                    0,
                    tP.liquidationPath
                );
            return amounts[amounts.length - 1];
        }
    }

    function liquidateFromPeg(address token, uint256 targetAmount)
        internal
        returns (uint256)
    {
        if (token == peg) {
            return targetAmount;
        } else {
            TokenPrice memory tP = tokenPrices[token];
            uint256[] memory amounts =
                MarginRouter(router()).authorizedSwapT4ExactT(
                    UNI,
                    targetAmount,
                    // TODO set an actual max peg input value
                    0,
                    tP.inverseLiquidationPath
                );
            return amounts[0];
        }
    }
}
