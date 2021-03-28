// SPDX-License-Identifier: GPL-2.0-only
pragma solidity ^0.8.0;

import "./BaseLending.sol";
import "./Fund.sol";

struct YieldAccumulator {
    uint256 accumulatorFP;
    uint256 lastUpdated;
    uint256 hourlyYieldFP;
}

struct HourlyBond {
    uint256 amount;
    uint256 yieldQuotientFP;
    uint256 moduloHour;
}

/// @dev Here we offer subscriptions to auto-renewing hourly bonds
/// Funds are locked in for an 50 minutes per hour, while interest rates float
abstract contract HourlyBondSubscriptionLending is BaseLending {
    uint256 withdrawalWindow = 10 minutes;
    // token => holder => bond record
    mapping(address => mapping(address => HourlyBond))
        public hourlyBondAccounts;

    mapping(address => YieldAccumulator) public hourlyBondYieldAccumulators;
    /// @dev accumulate interest per token (like compound indices)
    mapping(address => YieldAccumulator) public borrowYieldAccumulators;

    uint256 public borrowingFactorPercent = 200;

    mapping(address => uint256) public hourlyBondBuyingSpeed;
    mapping(address => uint256) public hourlyBondWithdrawingSpeed;

    function setHourlyYieldAPR(address token, uint256 aprPercent) external {
        require(
            isTokenActivator(msg.sender),
            "not authorized to set hourly yield"
        );
        if (hourlyBondYieldAccumulators[token].accumulatorFP == 0) {
            hourlyBondYieldAccumulators[token] = YieldAccumulator({
                accumulatorFP: FP32,
                lastUpdated: block.timestamp,
                hourlyYieldFP: (FP32 * (100 + aprPercent)) / 100 / (24 * 365)
            });
        } else {
            YieldAccumulator storage yA = getUpdatedHourlyYield(token);
            yA.hourlyYieldFP =
                (FP32 * (100 + aprPercent)) /
                100 /
                (24 * 365);
        }
    }

    function setWithdrawalWindow(uint256 window) external onlyOwner {
        withdrawalWindow = window;
    }

    function _makeHourlyBond(
        address token,
        address holder,
        uint256 amount
    ) internal {
        HourlyBond storage bond = hourlyBondAccounts[token][holder];
        updateHourlyBondAmount(token, bond);
        bond.yieldQuotientFP = hourlyBondYieldAccumulators[token].accumulatorFP;
        bond.moduloHour = block.timestamp % (1 hours);
        bond.amount += amount;
        lendingMeta[token].totalLending += amount;
    }

    function updateHourlyBondAmount(address token, HourlyBond storage bond)
        internal
    {
        uint256 yieldQuotientFP = bond.yieldQuotientFP;
        if (yieldQuotientFP > 0) {
            YieldAccumulator storage yA = getUpdatedHourlyYield(token);

            uint256 oldAmount = bond.amount;
            bond.amount = applyInterest(
                bond.amount,
                yA.accumulatorFP,
                yieldQuotientFP
            );

            uint256 deltaAmount = bond.amount - oldAmount;
            lendingMeta[token].totalLending += deltaAmount;
        }
    }

    // Retrieves bond balance for token and holder
    function viewHourlyBondAmount(address token, address holder)
        public
        view
        returns (uint256)
    {
        HourlyBond storage bond = hourlyBondAccounts[token][holder];
        uint256 yieldQuotientFP = bond.yieldQuotientFP;
        if (yieldQuotientFP > 0) {
            return
                bond.amount +
                applyInterest(
                    bond.amount,
                    viewCumulativeYieldFP(
                        token,
                        hourlyBondYieldAccumulators,
                        block.timestamp
                    ),
                    yieldQuotientFP
                );
        }
        return bond.amount + 0;
    }

    function _withdrawHourlyBond(
        address token,
        HourlyBond storage bond,
        address recipient,
        uint256 amount
    ) internal {
        // how far the current hour has advanced (relative to acccount hourly clock)
        uint256 currentOffset = (block.timestamp - bond.moduloHour) % (1 hours);

        require(
            withdrawalWindow >= currentOffset,
            "Tried withdrawing outside subscription cancellation time window"
        );

        Fund(fund()).withdraw(token, recipient, amount);

        bond.amount -= amount;
        lendingMeta[token].totalLending -= amount;
    }

    function closeHourlyBondAccount(address token) external {
        HourlyBond storage bond = hourlyBondAccounts[token][msg.sender];
        // apply all interest
        updateHourlyBondAmount(token, bond);
        _withdrawHourlyBond(token, bond, msg.sender, bond.amount);

        bond.amount = 0;
        bond.yieldQuotientFP = 0;
        bond.moduloHour = 0;
    }

    function calcCumulativeYieldFP(
        YieldAccumulator storage yieldAccumulator,
        uint256 timeDelta
    ) internal view returns (uint256 accumulatorFP) {
        uint256 secondsDelta = timeDelta % (1 hours);
        // linearly interpolate interest for seconds
        // accumulator * hourly_yield == seconds_per_hour * accumulator * hourly_yield / seconds_per_hour
        // FP * FP * 1 / (FP * 1) = FP
        accumulatorFP =
            (yieldAccumulator.accumulatorFP *
                yieldAccumulator.hourlyYieldFP *
                secondsDelta) /
            (FP32 * 1 hours);

        uint256 hoursDelta = timeDelta / (1 hours);
        if (hoursDelta > 0) {
            // This loop should hardly ever 1 or more unless something bad happened
            // In which case it costs gas but there isn't overflow
            for (uint256 i = 0; hoursDelta > i; i++) {
                // FP32 * FP32 / FP32 = FP32
                accumulatorFP =
                    (accumulatorFP * yieldAccumulator.hourlyYieldFP) /
                    FP32;
            }
        }
    }

    /// @dev updates yield accumulators for both borrowing and lending
    function getUpdatedHourlyYield(address token)
        internal
        returns (YieldAccumulator storage accumulator)
    {
        accumulator = hourlyBondYieldAccumulators[token];
        uint256 timeDelta = (block.timestamp - accumulator.lastUpdated);

        accumulator.accumulatorFP = calcCumulativeYieldFP(
            accumulator,
            timeDelta
        );

        LendingMetadata storage meta = lendingMeta[token];
        accumulator.hourlyYieldFP = updatedYieldFP(
            accumulator.hourlyYieldFP,
            accumulator.lastUpdated,
            meta.totalLending,
            lendingTarget(meta),
            hourlyBondBuyingSpeed[token],
            hourlyBondWithdrawingSpeed[token],
            maxHourlyYieldFP
        );

        YieldAccumulator storage borrowAccumulator =
            borrowYieldAccumulators[token];
        timeDelta = block.timestamp - borrowAccumulator.lastUpdated;
        borrowAccumulator.accumulatorFP = calcCumulativeYieldFP(
            borrowAccumulator,
            timeDelta
        );

        borrowYieldAccumulators[token].hourlyYieldFP =
            (borrowingFactorPercent * accumulator.hourlyYieldFP) /
            100;

        accumulator.lastUpdated = block.timestamp;
        borrowAccumulator.lastUpdated = block.timestamp;
    }

    function viewCumulativeYieldFP(
        address token,
        mapping(address => YieldAccumulator) storage yieldAccumulators,
        uint256 timestamp
    ) internal view returns (uint256) {
        uint256 timeDelta = (timestamp - yieldAccumulators[token].lastUpdated);
        return calcCumulativeYieldFP(yieldAccumulators[token], timeDelta);
    }
}
