// SPDX-License-Identifier: GPL-2.0-only
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

abstract contract PriceAware is Ownable, RoleAware {
    address public constant UNI = 0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f;
    address public peg;
    mapping(address => TokenPrice) public tokenPrices;
    /// update window in blocks
    uint16 public priceUpdateWindow = 8;
    uint256 public TEPID_UPDATE_RATE_PERMIL = 20;
    uint256 public CONFIDENT_UPDATE_RATE_PERMIL = 650;
    uint256 UPDATE_MAX_PEG_AMOUNT = 50_000;
    uint256 UPDATE_MIN_PEG_AMOUNT = 1_000;

    constructor(address _peg) Ownable() {
        peg = _peg;
    }

    function setPriceUpdateWindow(uint16 window) external onlyOwner {
        priceUpdateWindow = window;
    }

    function setTepidUpdateRate(uint256 rate) external onlyOwner {
        TEPID_UPDATE_RATE_PERMIL = rate;
    }

    function setConfidentUpdateRate(uint256 rate) external onlyOwner {
        CONFIDENT_UPDATE_RATE_PERMIL = rate;
    }

    function forcePriceUpdate(address token, uint256 inAmount)
        public
        returns (uint256)
    {
        return getUpdatedPriceInPeg(token, inAmount);
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
        if (
            block.number - tokenPrice.blockLastUpdated > priceUpdateWindow ||
            (forceCurBlock && block.number != tokenPrice.blockLastUpdated)
        ) {
            return getUpdatedPriceInPeg(token, inAmount);
        } else {
            return (inAmount * 1000 ether) / tokenPrice.tokenPer1k;
        }
    }

    function getUpdatedPriceInPeg(address token, uint256 inAmount)
        internal
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
                confidentUpdatePriceInPeg(tokenPrice, inAmount, outAmount);
            }

            return outAmount;
        }
    }

    /// Do a tepid update of price coming from a potentially unreliable source
    function tepidUpdatePriceInPeg(
        address token,
        uint256 inAmount,
        uint256 outAmount
    ) internal {
        _updatePriceInPeg(
            tokenPrices[token],
            inAmount,
            outAmount,
            TEPID_UPDATE_RATE_PERMIL
        );
    }

    function confidentUpdatePriceInPeg(
        TokenPrice storage tokenPrice,
        uint256 inAmount,
        uint256 outAmount
    ) internal {
        _updatePriceInPeg(
            tokenPrice,
            inAmount,
            outAmount,
            CONFIDENT_UPDATE_RATE_PERMIL
        );
        tokenPrice.blockLastUpdated = block.number;
    }

    function _updatePriceInPeg(
        TokenPrice storage tokenPrice,
        uint256 inAmount,
        uint256 outAmount,
        uint256 weightPerMil
    ) internal {
        uint256 updatePer1k = (1000 ether * inAmount) / outAmount;
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
            confidentUpdatePriceInPeg(tP, amount, outAmount);

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

            confidentUpdatePriceInPeg(tP, targetAmount, amounts[0]);

            return amounts[0];
        }
    }
}
