// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./RoleAware.sol";
import "./Fund.sol";

struct Claim {
    uint256 startingRewardRateFP;
    uint256 amount;
    uint256 intraDayGain;
    uint256 intraDayLoss;
}

/// @title Manage distribution of liquidity stake incentives
contract IncentiveDistribution is RoleAware, Ownable {
    // fixed point number factor
    uint256 internal constant FP32 = 2**32;
    // the amount of contraction per thousand, per day
    // of the overal daily incentive distribution
    // https://en.wikipedia.org/wiki/Per_mil
    uint256 public constant contractionPerMil = 999;
    address public immutable MFI;

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

    // how much is going to be distributed, contracts every day
    uint256 public currentDailyDistribution;

    // portion of daily distribution per each tranche
    mapping(uint256 => uint256) public trancheShare;
    uint256 public trancheShareTotal;
    uint256[] public allTranches;

    // tranche => claim totals for the period we're currently aggregating
    mapping(uint256 => uint256) public currentDayGains;
    mapping(uint256 => uint256) public currentDayLosses;

    // tranche => claim totals for the period we're currently aggregating
    mapping(uint256 => uint256) public tomorrowOngoingTotals;
    mapping(uint256 => uint256) public yesterdayOngoingTotals;

    mapping(uint256 => uint256) public intraDayGains;
    mapping(uint256 => uint256) public intraDayLosses;
    mapping(uint256 => uint256) public intraDayRewardGains;
    mapping(uint256 => uint256) public intraDayRewardLosses;

    // last updated day
    uint256 public lastUpdatedDay;

    // how each claim unit would get if they had staked from the dawn of time
    // expressed as fixed point number
    // claim amounts are expressed relative to this ongoing aggregate
    mapping(uint256 => uint256) public aggregateDailyRewardRateFP;
    mapping(uint256 => uint256) public yesterdayRewardRateFP;

    // claim records: tranche => user => claim
    mapping(uint256 => mapping(address => Claim)) public claims;

    mapping(address => uint256) public accruedReward;

    /// Set share of tranche
    function setTrancheShare(uint256 tranche, uint256 share)
        external
        onlyOwner
    {
        require(
            trancheShare[tranche] > 0,
            "Tranche is not initialized, please initialize first"
        );
        _setTrancheShare(tranche, share);
    }

    function _setTrancheShare(uint256 tranche, uint256 share) internal {
        if (share > trancheShare[tranche]) {
            trancheShareTotal += share - trancheShare[tranche];
        } else {
            trancheShareTotal -= trancheShare[tranche] - share;
        }
        trancheShare[tranche] = share;
    }

    /// Initialize tranche
    function initTranche(uint256 tranche, uint256 share) external onlyOwner {
        require(trancheShare[tranche] == 0, "Tranche already initialized");
        _setTrancheShare(tranche, share);

        // simply initialize to 1.0
        aggregateDailyRewardRateFP[tranche] = FP32;
        allTranches.push(tranche);
    }

    /// Start / increase amount of claim
    function addToClaimAmount(
        uint256 tranche,
        address recipient,
        uint256 claimAmount
    ) external {
        require(
            isIncentiveReporter(msg.sender),
            "Contract not authorized to report incentives"
        );
        if (currentDailyDistribution > 0) {
            Claim storage claim = claims[tranche][recipient];

            uint256 currentDay =
                claimAmount * (1 days - (block.timestamp % (1 days)));

            currentDayGains[tranche] += currentDay;
            claim.intraDayGain += currentDay * currentDailyDistribution;

            tomorrowOngoingTotals[tranche] += claimAmount * 1 days;
            updateAccruedReward(tranche, recipient, claim);

            claim.amount += claimAmount * (1 days);
        }
    }

    /// Decrease amount of claim
    function subtractFromClaimAmount(
        uint256 tranche,
        address recipient,
        uint256 subtractAmount
    ) external {
        require(
            isIncentiveReporter(msg.sender),
            "Contract not authorized to report incentives"
        );
        uint256 currentDay = subtractAmount * (block.timestamp % (1 days));

        Claim storage claim = claims[tranche][recipient];

        currentDayLosses[tranche] += currentDay;
        claim.intraDayLoss += currentDay * currentDailyDistribution;

        tomorrowOngoingTotals[tranche] -= subtractAmount * 1 days;

        updateAccruedReward(tranche, recipient, claim);
        claim.amount -= subtractAmount * (1 days);
    }

    function updateAccruedReward(
        uint256 tranche,
        address recipient,
        Claim storage claim
    ) internal {
        if (claim.startingRewardRateFP > 0) {
            accruedReward[recipient] += calcRewardAmount(tranche, claim);
        }
        // don't reward for current day (approximately)
        claim.startingRewardRateFP =
            yesterdayRewardRateFP[tranche] +
            aggregateDailyRewardRateFP[tranche];
    }

    /// @dev additional reward accrued since last update
    function calcRewardAmount(uint256 tranche, Claim storage claim)
        internal
        view
        returns (uint256 rewardAmount)
    {
        uint256 ours = claim.startingRewardRateFP;
        uint256 aggregate = aggregateDailyRewardRateFP[tranche];
        if (aggregate > ours) {
            rewardAmount = (claim.amount * (aggregate - ours)) / FP32;
        }
    }

    function applyIntraDay(
        uint256 tranche,
        uint256 rewardAmount,
        Claim storage claim
    ) internal view returns (uint256 reward) {
        uint256 gain = claim.intraDayGain;
        uint256 loss = claim.intraDayLoss;

        if (gain + loss > 0) {
            uint256 gainImpact =
                (gain * intraDayRewardGains[tranche]) /
                    (intraDayGains[tranche] + 1);
            uint256 lossImpact =
                (loss * intraDayRewardLosses[tranche]) /
                    (intraDayLosses[tranche] + 1);
            reward = rewardAmount + gainImpact - lossImpact;
        }
    }

    /// Get a view of reward amount
    function viewRewardAmount(uint256 tranche, address claimant)
        external
        view
        returns (uint256)
    {
        Claim storage claim = claims[tranche][claimant];
        uint256 rewardAmount =
            accruedReward[claimant] + calcRewardAmount(tranche, claim);
        return applyIntraDay(tranche, rewardAmount, claim);
    }

    /// Withdraw current reward amount
    function withdrawReward(uint256[] calldata tranches)
        external
        returns (uint256 withdrawAmount)
    {
        require(
            isIncentiveReporter(msg.sender),
            "Contract not authorized to report incentives"
        );

        updateDayTotals();
        for (uint256 i; tranches.length > i; i++) {
            uint256 tranche = tranches[i];
            Claim storage claim = claims[tranche][msg.sender];
            updateAccruedReward(tranche, msg.sender, claim);

            accruedReward[msg.sender] = applyIntraDay(
                tranche,
                accruedReward[msg.sender],
                claim
            );
            claim.intraDayGain = 0;
            claim.intraDayLoss = 0;
        }
        withdrawAmount = accruedReward[msg.sender];
        accruedReward[msg.sender] = 0;

        Fund(fund()).withdraw(MFI, msg.sender, withdrawAmount);
    }

    function updateDayTotals() internal {
        uint256 nowDay = block.timestamp / (1 days);
        uint256 dayDiff = nowDay - lastUpdatedDay;

        // shrink the daily distribution for every day that has passed
        for (uint256 i = 0; i < dayDiff; i++) {
            _updateTrancheTotals();

            currentDailyDistribution =
                (currentDailyDistribution * contractionPerMil) /
                1000;

            lastUpdatedDay += 1;
        }
    }

    function _updateTrancheTotals() internal {
        for (uint256 i; allTranches.length > i; i++) {
            uint256 tranche = allTranches[i];

            uint256 todayTotal =
                yesterdayOngoingTotals[tranche] +
                    currentDayGains[tranche] -
                    currentDayLosses[tranche];

            uint256 todayRewardRateFP =
                (FP32 * (currentDailyDistribution * trancheShare[tranche])) /
                    trancheShareTotal /
                    todayTotal;

            aggregateDailyRewardRateFP[tranche] += todayRewardRateFP;

            intraDayGains[tranche] +=
                currentDayGains[tranche] *
                currentDailyDistribution;

            intraDayLosses[tranche] +=
                currentDayLosses[tranche] *
                currentDailyDistribution;

            intraDayRewardGains[tranche] +=
                (currentDayGains[tranche] * todayRewardRateFP) /
                FP32;

            intraDayRewardLosses[tranche] +=
                (currentDayLosses[tranche] * todayRewardRateFP) /
                FP32;

            yesterdayOngoingTotals[tranche] = tomorrowOngoingTotals[tranche];
            currentDayGains[tranche] = 0;
            currentDayGains[tranche] = 0;
        }
    }
}
