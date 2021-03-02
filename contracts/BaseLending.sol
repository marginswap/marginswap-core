// SPDX-License-Identifier: GPL-2.0-only
pragma solidity ^0.8.0;
import "./RoleAware.sol";

abstract contract BaseLending is RoleAware, Ownable {
    uint256 constant FP32 = 2**32;
    uint256 constant ACCUMULATOR_INIT = 10**18;

    mapping(address => uint256) public totalLending;
    mapping(address => uint256) public totalBorrowed;
    // TODO init lending target with some amount out the gate
    mapping(address => uint256) public lendingTarget;
    mapping(address => uint256) public totalHourlyYieldFP;
    uint256 public yieldChangePerSecondFP;

    function applyInterest(
        uint256 balance,
        uint256 accumulatorFP,
        uint256 yieldQuotientFP
    ) internal pure returns (uint256) {
        // 1 * FP / FP = 1
        return (balance * accumulatorFP) / yieldQuotientFP;
    }

    function updatedYieldFP(
        uint256 _yieldFP,
        uint256 lastUpdated,
        uint256 totalLendingInBucket,
        uint256 bucketTarget,
        uint256 buying,
        uint256 withdrawing,
        uint256 bucketMaxYield
    ) internal view returns (uint256 yieldFP) {
        yieldFP = _yieldFP;
        uint256 timeDiff = block.timestamp - lastUpdated;
        uint256 yieldDiff = timeDiff * yieldChangePerSecondFP;

        if (
            totalLendingInBucket >= bucketTarget ||
            // TODO is this too restrictive?
            (buying >= withdrawing &&
                buying - withdrawing >= bucketTarget - totalLendingInBucket)
        ) {
            // TODO underflow
            yieldFP -= yieldDiff;
            if (FP32 > yieldFP) {
                yieldFP = FP32;
            }
        } else if (
            bucketTarget > totalLendingInBucket &&
            (withdrawing > buying ||
                bucketTarget - totalLendingInBucket > buying - withdrawing)
        ) {
            yieldFP += yieldDiff;
            if (yieldFP > bucketMaxYield) {
                yieldFP = bucketMaxYield;
            }
        }
    }

    function _makeFallbackBond(address token, address holder, uint256 amount) internal virtual; 
}
