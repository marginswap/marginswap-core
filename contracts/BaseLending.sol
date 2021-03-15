// SPDX-License-Identifier: GPL-2.0-only
pragma solidity ^0.8.0;
import "./RoleAware.sol";

abstract contract BaseLending is RoleAware, Ownable {
    uint256 constant FP32 = 2**32;
    uint256 constant ACCUMULATOR_INIT = 10**18;

    mapping(address => uint256) public totalLending;
    mapping(address => uint256) public totalBorrowed;
    // TODO init lending buffer and cap
    mapping(address => uint256) public lendingBuffer;
    mapping(address => uint256) public lendingCap;

    uint256 public maxHourlyYieldFP;
    uint256 public yieldChangePerSecondFP;

    /// @dev simple formula for calculating interest relative to accumulator
    function applyInterest(
        uint256 balance,
        uint256 accumulatorFP,
        uint256 yieldQuotientFP
    ) internal pure returns (uint256) {
        // 1 * FP / FP = 1
        return (balance * accumulatorFP) / yieldQuotientFP;
    }

    /// update the yield for an asset based on recent supply and demand
    function updatedYieldFP(
        // previous yield
        uint256 _yieldFP,
        // timestamp
        uint256 lastUpdated,
        uint256 totalLendingInBucket,
        uint256 bucketTarget,
        uint256 buyingSpeed,
        uint256 withdrawingSpeed,
        uint256 bucketMaxYield
    ) internal view returns (uint256 yieldFP) {
        yieldFP = _yieldFP;
        uint256 timeDiff = block.timestamp - lastUpdated;
        uint256 yieldDiff = timeDiff * yieldChangePerSecondFP;

        if (
            totalLendingInBucket >= bucketTarget ||
            buyingSpeed >= withdrawingSpeed
        ) {
            yieldFP -= min(yieldFP, yieldDiff);
        } else if (
            bucketTarget > totalLendingInBucket &&
            withdrawingSpeed > buyingSpeed
        ) {
            yieldFP += yieldDiff;
            if (yieldFP > bucketMaxYield) {
                yieldFP = bucketMaxYield;
            }
        }
    }

    /// @dev minimum
    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a > b) {
            return b;
        } else {
            return a;
        }
    }

    function _makeFallbackBond(
        address token,
        address holder,
        uint256 amount
    ) internal virtual;

    function lendingTarget(address token) public view returns (uint256) {
        return
            min(lendingCap[token], totalBorrowed[token] + lendingBuffer[token]);
    }

    function setLendingCap(address token, uint256 cap) external {
        require(
            isTokenActivator(msg.sender),
            "not authorized to set lending cap"
        );
        lendingCap[token] = cap;
    }

    function setLendingBuffer(address token, uint256 buffer) external {
        require(
            isTokenActivator(msg.sender),
            "not autorized to set lending buffer"
        );
        lendingBuffer[token] = buffer;
    }

    function setMaxHourlyYieldFP(uint256 maxYieldFP) external onlyOwner {
        maxHourlyYieldFP = maxYieldFP;
    }

    function setYieldChangePerSecondFP(uint256 changePerSecondFP)
        external
        onlyOwner
    {
        yieldChangePerSecondFP = changePerSecondFP;
    }
}
