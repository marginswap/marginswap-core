// SPDX-License-Identifier: GPL-2.0-only
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./RoleAware.sol";
import "./Fund.sol";

struct Claim {
    uint256 startingRewardRateFP;
    address recipient;
    uint256 amount;
}

contract IncentiveDistribution is RoleAware, Ownable {
    uint256 constant FP32 = 2**32;
    uint256 contractionPerMil = 999;
    address MFI;

    constructor(
        address _MFI,
        uint256 startingDailyDistributionWithoutDecimals,
        address _roles
    ) RoleAware(_roles) Ownable() {
        MFI = _MFI;
        currentDailyDistribution =
            startingDailyDistributionWithoutDecimals *
            (1 ether);
    }

    uint256 public currentDailyDistribution;
    mapping(uint8 => uint256) public trancheShare;
    uint256 public trancheShareTotal;

    // TODO initialize non-zero
    mapping(uint8 => uint256) public currentDayTotals;
    mapping(uint8 => uint256[24]) public hourlyTotals;
    mapping(uint8 => uint256) public currentHourTotals;
    mapping(uint8 => uint256) public lastUpdatedHours;
    // carry-over totals
    mapping(uint8 => uint256) public ongoingTotals;

    // Here's the crux: rewards are aggregated hourly for ongoing incentive distribution
    // If e.g. a lender keeps their money in for several days, then their reward is going to be
    // amount * (reward_rate_hour1 + reward_rate_hour2 + reward_rate_hour3...)
    // where reward_rate is the amount of incentive per trade volume / lending volume
    mapping(uint8 => uint256) public aggregateHourlyRewardRateFP;
    mapping(uint256 => Claim) public claims;
    uint256 public nextClaimId;

    function setTrancheShare(uint8 tranche, uint256 share) external onlyOwner {
        require(
            lastUpdatedHours[tranche] > 0,
            "Tranche is not initialized, please initialize first"
        );
        _setTrancheShare(tranche, share);
    }

    function _setTrancheShare(uint8 tranche, uint256 share) internal {
        if (share > trancheShare[tranche]) {
            trancheShareTotal += share - trancheShare[tranche];
        } else {
            trancheShareTotal -= trancheShare[tranche] - share;
        }
        trancheShare[tranche] = share;
    }

    function initTranche(
        uint8 tranche,
        uint256 share,
        uint256 assumedInitialDailyTotal
    ) external onlyOwner {
        _setTrancheShare(tranche, share);

        currentDayTotals[tranche] = assumedInitialDailyTotal;
        uint256 assumedHourlyTotal = assumedInitialDailyTotal / 24;
        for (uint256 hour = 0; hour < 24; hour++) {
            hourlyTotals[tranche][hour] = assumedHourlyTotal;
        }

        lastUpdatedHours[tranche] = block.timestamp / (1 hours);
        aggregateHourlyRewardRateFP[tranche] = FP32;
    }

    function getSpotReward(
        uint8 tranche,
        address recipient,
        uint256 spotAmount
    ) external {
        require(
            isIncentiveReporter(msg.sender),
            "Contract not authorized to report incentives"
        );

        updateHourTotals(tranche);
        currentHourTotals[tranche] += spotAmount;
        uint256 rewardAmount =
            (spotAmount * currentHourlyRewardRateFP(tranche)) / FP32;
        Fund(fund()).withdraw(MFI, recipient, rewardAmount);
    }

    function updateHourTotals(uint8 tranche) internal {
        uint256 currentHour = block.timestamp / (1 hours);

        // Do a bunch of updating of hourly variables when the hour changes

        for (
            uint256 lastUpdatedHour = lastUpdatedHours[tranche];
            lastUpdatedHour < currentHour;
            lastUpdatedHour++
        ) {
            uint256 hourOfDay = lastUpdatedHour % 24;
            aggregateHourlyRewardRateFP[tranche] += currentHourlyRewardRateFP(
                tranche
            );
            // rotate out the daily totals
            currentDayTotals[tranche] -= hourlyTotals[tranche][hourOfDay];
            hourlyTotals[tranche][hourOfDay] = currentHourTotals[tranche];
            currentDayTotals[tranche] += hourlyTotals[tranche][hourOfDay];

            // carry over any ongoing claims
            currentHourTotals[tranche] = ongoingTotals[tranche];

            // switch the distribution amount at day changes
            if (hourOfDay + 1 == 24) {
                currentDailyDistribution =
                    (currentDailyDistribution * contractionPerMil) /
                    1000;
            }
            lastUpdatedHours[tranche] = currentHour;
        }
    }

    function forceHourTotalUpdate(uint8 tranche) external {
        updateHourTotals(tranche);
    }

    function currentHourlyRewardRateFP(uint8 tranche)
        internal
        view
        returns (uint256)
    {
        uint256 trancheDailyDistributionFP =
            (FP32 * (currentDailyDistribution * trancheShare[tranche])) /
                trancheShareTotal;
        return trancheDailyDistributionFP / currentDayTotals[tranche] / 24;
    }

    function startClaim(
        uint8 tranche,
        address recipient,
        uint256 claimAmount
    ) external returns (uint256) {
        require(
            isIncentiveReporter(msg.sender),
            "Contract not authorized to report incentives"
        );
        updateHourTotals(tranche);
        ongoingTotals[tranche] += claimAmount;
        currentHourTotals[tranche] += claimAmount;
        claims[nextClaimId] = Claim({
            startingRewardRateFP: aggregateHourlyRewardRateFP[tranche],
            recipient: recipient,
            amount: claimAmount
        });
        nextClaimId += 1;
        return nextClaimId - 1;
    }

    function addToClaimAmount(
        uint8 tranche,
        uint256 claimId,
        uint256 additionalAmount
    ) external {
        require(
            isIncentiveReporter(msg.sender),
            "Contract not authorized to report incentives"
        );
        updateHourTotals(tranche);

        Claim storage claim = claims[claimId];
        // add all rewards accrued up to now
        claim.startingRewardRateFP -=
            (claim.amount * FP32) /
            calcRewardAmount(tranche, claim);
        claim.amount += additionalAmount;
    }

    function subtractFromClaimAmount(
        uint8 tranche,
        uint256 claimId,
        uint256 subtractAmount
    ) external {
        require(
            isIncentiveReporter(msg.sender),
            "Contract not authorized to report incentives"
        );
        updateHourTotals(tranche);

        Claim storage claim = claims[claimId];
        // add all rewards accrued up to now
        claim.startingRewardRateFP -=
            (claim.amount * FP32) /
            calcRewardAmount(tranche, claim);
        claim.amount -= subtractAmount;
    }

    function endClaim(uint8 tranche, uint256 claimId) external {
        require(
            isIncentiveReporter(msg.sender),
            "Contract not authorized to report incentives"
        );
        updateHourTotals(tranche);
        Claim storage claim = claims[claimId];
        // TODO what if empty?
        uint256 rewardAmount = calcRewardAmount(tranche, claim);
        Fund(fund()).withdraw(MFI, claim.recipient, rewardAmount);
        delete claim.recipient;
        delete claim.startingRewardRateFP;
        delete claim.amount;
    }

    function calcRewardAmount(uint8 tranche, Claim storage claim)
        internal
        view
        returns (uint256)
    {
        return
            (claim.amount *
                (aggregateHourlyRewardRateFP[tranche] -
                    claim.startingRewardRateFP)) / FP32;
    }
}
