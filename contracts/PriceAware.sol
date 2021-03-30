// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "./RoleAware.sol";
import "./MarginRouter.sol";

/// Stores how many of token you could get for 1k of peg
struct TokenPrice {
    uint256 blockLastUpdated;
    uint256 tokenPer1k;
    address[] liquidationPath;
    address[] inverseLiquidationPath;
}

/// @dev The protocol features several mechanisms to prevent vulnerability to
/// price manipulation:
/// 1) global exposure caps on all tokens which need to be raised gradually
///    during the process of introducing a new token, making attacks unprofitable
///    due to lack  of scale
/// 2) Exponential moving average with cautious price update. Prices for estimating
///    how much a trader can borrow need not be extremely current and precise, mainly
///    they must be resilient against extreme manipulation
/// 3) Liquidators may not call from a contract address, to prevent extreme forms of
///    of front-running and other price manipulation.
abstract contract PriceAware is Ownable, RoleAware {
    address public constant UNI = 0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f;
    address public peg;
    mapping(address => TokenPrice) public tokenPrices;
    /// update window in blocks
    uint16 public priceUpdateWindow = 8;
    uint256 public UPDATE_RATE_PERMIL = 80;
    uint256 UPDATE_MAX_PEG_AMOUNT = 50_000;
    uint256 UPDATE_MIN_PEG_AMOUNT = 1_000;

    constructor(address _peg) Ownable() {
        peg = _peg;
    }

    function setPriceUpdateWindow(uint16 window) external onlyOwner {
        priceUpdateWindow = window;
    }

    function setConfidentUpdateRate(uint256 rate) external onlyOwner {
        UPDATE_RATE_PERMIL = rate;
    }

    function encouragePriceUpdate(address token, uint256 inAmount)
        external
        returns (uint256)
    {
        return getCurrentPriceInPeg(token, inAmount, true);
    }

    function setUpdateMaxPegAmount(uint256 amount) external onlyOwner {
        UPDATE_MAX_PEG_AMOUNT = amount;
    }

    function setUpdateMinPegAmount(uint256 amount) external onlyOwner {
        UPDATE_MIN_PEG_AMOUNT = amount;
    }

    function getCurrentPriceInPeg(
        address token,
        uint256 inAmount,
        bool forceCurBlock
    ) internal returns (uint256) {
        TokenPrice storage tokenPrice = tokenPrices[token];
        if (forceCurBlock) {
            if (block.number - tokenPrice.blockLastUpdated > priceUpdateWindow) {
                // update the currently cached price
                return getUpdatedPriceInPeg(token, inAmount);
            } else {
                // just get the current price from AMM
                return viewCurrentPriceInPeg(token, inAmount);
            }
        } else if (tokenPrice.tokenPer1k == 0) {
            // do the best we can if it's at zero
            return getUpdatedPriceInPeg(token, inAmount);
        }

        if (block.number - tokenPrice.blockLastUpdated > priceUpdateWindow) {
            // update the price somewhat
            getUpdatedPriceInPeg(token, inAmount);
        }

        return (inAmount * 1000 ether) / tokenPrice.tokenPer1k;
    }

    function viewCurrentPriceInPeg(address token, uint256 inAmount)
        internal
        view
        returns (uint256)
    {
        if (token == peg) {
            return inAmount;
        } else {
            TokenPrice storage tokenPrice = tokenPrices[token];
            uint256[] memory pathAmounts =
                MarginRouter(router()).getAmountsOut(
                    UNI,
                    inAmount,
                    tokenPrice.liquidationPath
                );
            uint256 outAmount = pathAmounts[pathAmounts.length - 1];
            return outAmount;
        }
    }

    function getUpdatedPriceInPeg(address token, uint256 inAmount)
        internal
        virtual
        returns (uint256)
    {
        if (token == peg) {
            return inAmount;
        } else {
            TokenPrice storage tokenPrice = tokenPrices[token];
            uint256[] memory pathAmounts =
                MarginRouter(router()).getAmountsOut(
                    UNI,
                    inAmount,
                    tokenPrice.liquidationPath
                );
            uint256 outAmount = pathAmounts[pathAmounts.length - 1];

            if (
                outAmount > UPDATE_MIN_PEG_AMOUNT &&
                outAmount < UPDATE_MAX_PEG_AMOUNT
            ) {
                updatePriceInPeg(tokenPrice, inAmount, outAmount);
            }

            return outAmount;
        }
    }

    function updatePriceInPeg(
        TokenPrice storage tokenPrice,
        uint256 inAmount,
        uint256 outAmount
    ) internal {
        _updatePriceInPeg(
            tokenPrice,
            inAmount,
            outAmount,
            UPDATE_RATE_PERMIL
        );
        tokenPrice.blockLastUpdated = block.number;
    }

    function _updatePriceInPeg(
        TokenPrice storage tokenPrice,
        uint256 inAmount,
        uint256 outAmount,
        uint256 weightPerMil
    ) internal {
        uint256 updatePer1k = (1000 ether * inAmount) / (outAmount + 1);
        tokenPrice.tokenPer1k =
            (tokenPrice.tokenPer1k *
                (1000 - weightPerMil) +
                updatePer1k *
                weightPerMil) /
            1000;
    }

    // add path from token to current liquidation peg
    function setLiquidationPath(address[] memory path) external {
        require(
            isTokenActivator(msg.sender),
            "not authorized to set lending cap"
        );
        address token = path[0];
        tokenPrices[token].liquidationPath = new address[](path.length);
        tokenPrices[token].inverseLiquidationPath = new address[](path.length);

        for (uint16 i = 0; path.length > i; i++) {
            tokenPrices[token].liquidationPath[i] = path[i];
            tokenPrices[token].inverseLiquidationPath[i] = path[
                path.length - i - 1
            ];
        }
        uint256[] memory pathAmounts =
            MarginRouter(router()).getAmountsIn(UNI, 1000 ether, path);
        uint256 inAmount = pathAmounts[0];
        _updatePriceInPeg(tokenPrices[token], inAmount, 1000 ether, 1000);
    }

    function liquidateToPeg(address token, uint256 amount)
        internal
        returns (uint256)
    {
        if (token == peg) {
            return amount;
        } else {
            TokenPrice storage tP = tokenPrices[token];
            uint256[] memory amounts =
                MarginRouter(router()).authorizedSwapExactT4T(
                    UNI,
                    amount,
                    0,
                    tP.liquidationPath
                );

            uint256 outAmount = amounts[amounts.length - 1];

            return outAmount;
        }
    }

    function liquidateFromPeg(address token, uint256 targetAmount)
        internal
        returns (uint256)
    {
        if (token == peg) {
            return targetAmount;
        } else {
            TokenPrice storage tP = tokenPrices[token];
            uint256[] memory amounts =
                MarginRouter(router()).authorizedSwapT4ExactT(
                    UNI,
                    targetAmount,
                    type(uint256).max,
                    tP.inverseLiquidationPath
                );

            return amounts[0];
        }
    }
}
