// SPDX-License-Identifier: GPL-2.0-only
pragma solidity ^0.8.0;

import "../CrossMarginTrading.sol";

address constant TEST_PEG = 0x0000000000000000000000000000000000000010;
address constant TRADER_ONE = 0x0000000000000000000000000000000000000001;

contract CrossMarginTradingTest is CrossMarginTrading {
    constructor(address _roles) CrossMarginTrading(TEST_PEG, _roles) {
        coolingOffPeriod = 0;
    }

    function getUpdatedPriceInPeg(address token, uint256 inAmount)
        internal
        override
        returns (uint256)
    {
        if (inAmount > 0) {
            confidentUpdatePriceInPeg(tokenPrices[token], inAmount, inAmount);
        }
        return inAmount;
    }
}
