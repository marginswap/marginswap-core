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
    uint256 constant contractionPerMil = 999;
    uint256 constant period = 4 hours;
    uint256 constant periodsPerDay = 24 hours / period;
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
    mapping(uint8 => uint256[periodsPerDay]) public periodTotals;
    mapping(uint8 => uint256) public currentPeriodTotals;
    mapping(uint8 => uint256) public lastUpdatedPeriods;
    // carry-over totals
    mapping(uint8 => uint256) public ongoingTotals;

    mapping(uint8 => uint256) public aggregatePeriodicRewardRateFP;
    mapping(uint256 => Claim) public claims;
    uint256 public nextClaimId;

    function setTrancheShare(uint8 tranche, uint256 share) external onlyOwner {
        require(
            lastUpdatedPeriods[tranche] > 0,
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
        uint256 assumedPeriodTotal = assumedInitialDailyTotal / periodsPerDay;
        for (
            uint256 periodOfDay = 0;
            periodOfDay < periodsPerDay;
            periodOfDay++
        ) {
            periodTotals[tranche][periodOfDay] = assumedPeriodTotal;
        }

        lastUpdatedPeriods[tranche] = block.timestamp / period;
        aggregatePeriodicRewardRateFP[tranche] = FP32;
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

        updatePeriodTotals(tranche);
        currentPeriodTotals[tranche] += spotAmount;
        uint256 rewardAmount =
            (spotAmount * currentPeriodicRewardRateFP(tranche)) / FP32;
        Fund(fund()).withdraw(MFI, recipient, rewardAmount);
    }

    function updatePeriodTotals(uint8 tranche) internal {
        uint256 currentPeriod = block.timestamp / period;

        // Do a bunch of updating of periodic variables when the period changes

        for (
            uint256 lastUpdatedPeriod = lastUpdatedPeriods[tranche];
            lastUpdatedPeriod < currentPeriod;
            lastUpdatedPeriod++
        ) {
            uint256 periodOfDay = lastUpdatedPeriod % periodsPerDay;
            aggregatePeriodicRewardRateFP[
                tranche
            ] += currentPeriodicRewardRateFP(tranche);
            // rotate out the daily totals
            currentDayTotals[tranche] -= periodTotals[tranche][periodOfDay];
            periodTotals[tranche][periodOfDay] = currentPeriodTotals[tranche];
            currentDayTotals[tranche] += periodTotals[tranche][periodOfDay];

            // carry over any ongoing claims
            currentPeriodTotals[tranche] = ongoingTotals[tranche];

            // switch the distribution amount at day changes
            if (periodOfDay + 1 == periodsPerDay) {
                currentDailyDistribution =
                    (currentDailyDistribution * contractionPerMil) /
                    1000;
            }
            lastUpdatedPeriods[tranche] = currentPeriod;
        }
    }

    function forcePeriodTotalUpdate(uint8 tranche) external {
        updatePeriodTotals(tranche);
    }

    function currentPeriodicRewardRateFP(uint8 tranche)
        internal
        view
        returns (uint256)
    {
        uint256 trancheDailyDistributionFP =
            (FP32 * (currentDailyDistribution * trancheShare[tranche])) /
                trancheShareTotal;
        return
            trancheDailyDistributionFP /
            currentDayTotals[tranche] /
            periodsPerDay;
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
        updatePeriodTotals(tranche);
        ongoingTotals[tranche] += claimAmount;
        currentPeriodTotals[tranche] += claimAmount;
        claims[nextClaimId] = Claim({
            startingRewardRateFP: aggregatePeriodicRewardRateFP[tranche],
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
        updatePeriodTotals(tranche);

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
        updatePeriodTotals(tranche);

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
        updatePeriodTotals(tranche);
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
                (aggregatePeriodicRewardRateFP[tranche] -
                    claim.startingRewardRateFP)) / FP32;
    }
}
