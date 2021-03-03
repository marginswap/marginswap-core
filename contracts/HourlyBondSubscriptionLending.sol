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

// TODO totalHourlyYieldFP
abstract contract HourlyBondSubscriptionLending is BaseLending {
    uint256 constant WITHDRAWAL_WINDOW = 10 minutes;
    mapping(address => mapping(address => HourlyBond))
        public hourlyBondAccounts;
    mapping(address => YieldAccumulator) public hourlyBondYieldAccumulators;
    mapping(address => uint256) public totalHourlyBond;
    mapping(address => uint256) public hourlyBondBuyingSpeed;
    mapping(address => uint256) public hourlyBondWithdrawingSpeed;
    uint256 public hourlyMaxYield;

    function buyHourlyBondSubscription(address token, uint256 amount) external {
        if (lendingTarget[token] >= totalLending[token] + amount) {
            require(
                Fund(fund()).deposit(token, amount),
                "Could not transfer bond deposit token to fund"
            );
            _makeHourlyBond(token, msg.sender, amount);
        }
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
        totalHourlyBond[token] += amount;
        totalLending[token] += amount;
    }

    function updateHourlyBondAmount(address token, HourlyBond storage bond)
        internal
    {
        uint256 yieldQuotientFP = bond.yieldQuotientFP;
        if (yieldQuotientFP > 0) {
            YieldAccumulator storage yA =
                getUpdatedCumulativeYield(
                    token,
                    hourlyBondYieldAccumulators,
                    block.timestamp
                );

            uint256 oldAmount = bond.amount;
            bond.amount = applyInterest(
                bond.amount,
                yA.accumulatorFP,
                yieldQuotientFP
            );

            uint256 deltaAmount = bond.amount - oldAmount;
            totalHourlyBond[token] += deltaAmount;
            totalLending[token] += deltaAmount;
            // TODO make a similar update for borrowing!
        }
    }

    function withdrawHourlyBond(address token, uint256 amount) external {
        HourlyBond storage bond = hourlyBondAccounts[token][msg.sender];
        // apply all interest
        updateHourlyBondAmount(token, bond);
        _withdrawHourlyBond(token, bond, msg.sender, amount);
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
            WITHDRAWAL_WINDOW >= currentOffset,
            "Tried withdrawing outside subscription cancellation time window"
        );

        require(
            Fund(fund()).withdraw(token, recipient, amount),
            "Insufficient liquidity"
        );

        bond.amount -= amount;
        totalHourlyBond[token] -= amount;
        totalLending[token] -= amount;
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

    function calcCumulativeYield(
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

    function getUpdatedCumulativeYield(
        address token,
        mapping(address => YieldAccumulator) storage yieldAccumulators,
        uint256 timestamp
    ) internal returns (YieldAccumulator storage accumulator) {
        accumulator = yieldAccumulators[token];
        accumulator.hourlyYieldFP = updatedYieldFP(
            accumulator.hourlyYieldFP,
            accumulator.lastUpdated,
            totalLending[token],
            lendingTarget[token],
            hourlyBondBuyingSpeed[token],
            hourlyBondWithdrawingSpeed[token],
            hourlyMaxYield
        );

        uint256 timeDelta = (timestamp - accumulator.lastUpdated);
        accumulator.accumulatorFP = calcCumulativeYield(accumulator, timeDelta);
    }

    function viewCumulativeYield(
        address token,
        mapping(address => YieldAccumulator) storage yieldAccumulators,
        uint256 timestamp
    ) internal view returns (uint256) {
        uint256 timeDelta = (timestamp - yieldAccumulators[token].lastUpdated);
        return calcCumulativeYield(yieldAccumulators[token], timeDelta);
    }
}
