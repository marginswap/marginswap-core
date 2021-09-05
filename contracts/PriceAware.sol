// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "./RoleAware.sol";
import "./MarginRouter.sol";
import "../libraries/UniswapStyleLib.sol";
import "../interfaces/IOracle.sol";

/// Stores how many of token you could get for 1k of peg
struct TokenPrice {
    uint256 lastUpdated;
    uint256 priceFP;
    address[] liquidationTokens;
    bytes32 amms;
    address[] inverseLiquidationTokens;
    bytes32 inverseAmms;
}

struct VolatilitySetting {
    uint256 priceUpdateWindow;
    uint256 updateRatePermil;
    uint256 voluntaryUpdateWindow;
}

struct PairPrice {
    uint256 cumulative;
    uint256 lastUpdated;
    uint256 priceFP;
}

/// @title The protocol features several mechanisms to prevent vulnerability to
/// price manipulation:
/// 1) global exposure caps on all tokens which need to be raised gradually
///    during the process of introducing a new token, making attacks unprofitable
///    due to lack  of scale
/// 2) Exponential moving average with cautious price update. Prices for estimating
///    how much a trader can borrow need not be extremely current and precise, mainly
///    they must be resilient against extreme manipulation
/// 3) Liquidators may not call from a contract address, to prevent extreme forms of
///    of front-running and other price manipulation.
abstract contract PriceAware is RoleAware, UniswapStyleLib {
    uint256 constant FP112 = 2**112;
    uint256 constant FP8 = 2**8;
    uint256 constant FP96 = 2**(112 - 2 * 8);

    address public immutable peg;

    mapping(address => TokenPrice) public tokenPrices;
    mapping(address => mapping(address => PairPrice)) public pairPrices;

    mapping(address => IOracle) public oracles;

    /// update window in blocks
    uint256 public priceUpdateWindow = 20 minutes;
    uint256 public voluntaryUpdateWindow = 5 minutes;

    uint256 public UPDATE_RATE_PERMIL = 400;
    VolatilitySetting[] public volatilitySettings;

    constructor(address _peg) {
        peg = _peg;
    }

    /// Set price oracle
    function setPriceOracle(address token, address oracle)
        external
        onlyOwnerExecActivator
    {
        oracles[token] = IOracle(oracle);
    }

    /// Set window for price updates
    function setPriceUpdateWindow(uint16 window, uint256 voluntaryWindow)
        external
        onlyOwnerExec
    {
        priceUpdateWindow = window;
        voluntaryUpdateWindow = voluntaryWindow;
    }

    /// Add a new volatility setting
    function addVolatilitySetting(
        uint256 _priceUpdateWindow,
        uint256 _updateRatePermil,
        uint256 _voluntaryUpdateWindow
    ) external onlyOwnerExec {
        volatilitySettings.push(
            VolatilitySetting({
                priceUpdateWindow: _priceUpdateWindow,
                updateRatePermil: _updateRatePermil,
                voluntaryUpdateWindow: _voluntaryUpdateWindow
            })
        );
    }

    /// Choose a volatitlity setting
    function chooseVolatilitySetting(uint256 index)
        external
        onlyOwnerExecDisabler
    {
        VolatilitySetting storage vs = volatilitySettings[index];
        if (vs.updateRatePermil > 0) {
            UPDATE_RATE_PERMIL = vs.updateRatePermil;
            priceUpdateWindow = vs.priceUpdateWindow;
            voluntaryUpdateWindow = vs.voluntaryUpdateWindow;
        }
    }

    /// Set rate for updates
    function setUpdateRate(uint256 rate) external onlyOwnerExec {
        UPDATE_RATE_PERMIL = rate;
    }

    function getCurrentPriceInPeg(address token, uint256 inAmount)
        internal
        returns (uint256)
    {
        return getCurrentPriceInPeg(token, inAmount, false);
    }

    function getCurrentPriceInPeg(
        address token,
        uint256 inAmount,
        bool voluntary
    ) public returns (uint256 priceInPeg) {
        IOracle o = oracles[token];
        if (address(o) != address(0)) {
            return o.getCurrentPrice(token, inAmount);
        } else if (token == peg) {
            return inAmount;
        } else {
            TokenPrice storage tokenPrice = tokenPrices[token];

            uint256 timeDelta = block.timestamp - tokenPrice.lastUpdated;
            if (
                timeDelta > priceUpdateWindow ||
                tokenPrice.priceFP == 0 ||
                (voluntary && timeDelta > voluntaryUpdateWindow)
            ) {
                // update the currently cached price
                uint256 priceUpdateFP;
                priceUpdateFP = getPriceByPairs(
                    tokenPrice.liquidationTokens,
                    tokenPrice.amms
                );
                _setPriceVal(tokenPrice, priceUpdateFP, UPDATE_RATE_PERMIL);
            }

            priceInPeg = (inAmount * tokenPrice.priceFP) / FP112;
        }
    }

    /// Get view of current price of token in peg
    function viewCurrentPriceInPeg(address token, uint256 inAmount)
        public
        view
        returns (uint256 priceInPeg)
    {
        IOracle o = oracles[token];
        if (address(o) != address(0)) {
            return o.viewCurrentPrice(token, inAmount);
        } else if (token == peg) {
            return inAmount;
        } else {
            TokenPrice storage tokenPrice = tokenPrices[token];
            uint256 priceFP = tokenPrice.priceFP;

            priceInPeg = (inAmount * priceFP) / FP112;
        }
    }

    function _setPriceVal(
        TokenPrice storage tokenPrice,
        uint256 updateFP,
        uint256 weightPerMil
    ) internal {
        tokenPrice.priceFP =
            (tokenPrice.priceFP *
                (1000 - weightPerMil) +
                updateFP *
                weightPerMil) /
            1000;

        tokenPrice.lastUpdated = block.timestamp;
    }

    /// add path from token to current liquidation peg
    function setLiquidationPath(bytes32 amms, address[] memory tokens)
        external
        onlyOwnerExecActivator
    {
        address token = tokens[0];

        if (token != peg) {
            TokenPrice storage tokenPrice = tokenPrices[token];

            tokenPrice.amms = amms;

            tokenPrice.liquidationTokens = tokens;
            tokenPrice.inverseLiquidationTokens = new address[](tokens.length);

            bytes32 inverseAmms;

            for (uint256 i = 0; tokens.length - 1 > i; i++) {
                initPairPrice(tokens[i], tokens[i + 1], amms[i]);

                bytes32 shifted =
                    bytes32(amms[i]) >> ((tokens.length - 2 - i) * 8);

                inverseAmms = inverseAmms | shifted;
            }

            tokenPrice.inverseAmms = inverseAmms;

            for (uint256 i = 0; tokens.length > i; i++) {
                tokenPrice.inverseLiquidationTokens[i] = tokens[
                    tokens.length - i - 1
                ];
            }

            tokenPrice.priceFP = getPriceByPairs(tokens, amms);
            tokenPrice.lastUpdated = block.timestamp;
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
                MarginRouter(marginRouter()).authorizedSwapExactT4T(
                    amount,
                    0,
                    tP.amms,
                    tP.liquidationTokens
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
                MarginRouter(marginRouter()).authorizedSwapT4ExactT(
                    targetAmount,
                    type(uint256).max,
                    tP.amms,
                    tP.inverseLiquidationTokens
                );

            return amounts[0];
        }
    }

    function getPriceByPairs(address[] memory tokens, bytes32 amms)
        internal
        returns (uint256 priceFP)
    {
        priceFP = FP112;
        for (uint256 i; i < tokens.length - 1; i++) {
            address inToken = tokens[i];
            address outToken = tokens[i + 1];

            address pair =
                amms[i] == 0
                    ? UniswapStyleLib.pairForAMM1(inToken, outToken)
                    : UniswapStyleLib.pairForAMM2(inToken, outToken);

            PairPrice storage pairPrice = pairPrices[pair][inToken];

            (, , uint256 pairLastUpdated) = IUniswapV2Pair(pair).getReserves();
            uint256 timeDelta = pairLastUpdated - pairPrice.lastUpdated;

            if (timeDelta > voluntaryUpdateWindow) {
                // we are in business
                (address token0, ) =
                    UniswapStyleLib.sortTokens(inToken, outToken);

                uint256 cumulative =
                    inToken == token0
                        ? IUniswapV2Pair(pair).price0CumulativeLast()
                        : IUniswapV2Pair(pair).price1CumulativeLast();

                uint256 pairPriceFP =
                    (cumulative - pairPrice.cumulative) / timeDelta;
                priceFP = scaleMul(priceFP, pairPriceFP);

                pairPrice.priceFP = pairPriceFP;
                pairPrice.cumulative = cumulative;
                pairPrice.lastUpdated = pairLastUpdated;
            } else {
                priceFP = scaleMul(priceFP, pairPrice.priceFP);
            }
        }
    }

    function scaleMul(uint256 a, uint256 b) internal pure returns (uint256) {
        return ((a / FP8) * (b / FP8)) / FP96;
    }

    function initPairPrice(
        address inToken,
        address outToken,
        bytes1 amm
    ) internal {
        address pair =
            amm == 0
                ? UniswapStyleLib.pairForAMM1(inToken, outToken)
                : UniswapStyleLib.pairForAMM2(inToken, outToken);

        PairPrice storage pairPrice = pairPrices[pair][inToken];

        if (pairPrice.lastUpdated == 0) {
            (uint112 reserve0, uint112 reserve1, uint256 pairLastUpdated) =
                IUniswapV2Pair(pair).getReserves();

            (address token0, ) = UniswapStyleLib.sortTokens(inToken, outToken);

            if (inToken == token0) {
                pairPrice.priceFP = (FP112 * reserve1) / reserve0;
                pairPrice.cumulative = IUniswapV2Pair(pair)
                    .price0CumulativeLast();
            } else {
                pairPrice.priceFP = (FP112 * reserve0) / reserve1;
                pairPrice.cumulative = IUniswapV2Pair(pair)
                    .price1CumulativeLast();
            }

            pairPrice.lastUpdated = block.timestamp;

            pairPrice.lastUpdated = pairLastUpdated;
        }
    }
}
