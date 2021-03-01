import "./RoleAware.sol";

struct Claim {
    uint256 startingRewardRate;
    address recipient;
    uint256 amount;
}

contract IncentiveDistribution is RoleAware, Ownable {
    uint256 contractionPerMil = 999;

    constructor(address _roles) RoleAware(_roles) Ownable() {}

    uint256 public currentDailyDistribution;
    uint256[] public tranchePercentShare;
    // TODO init to something non-zero
    mapping(uint8 => uint256) public currentDayTotals;
    mapping(uint8 => uint256[24]) public hourlyTotals;
    mapping(uint8 => uint256) public currentHourTotals;
    mapping(uint8 => uint256) public lastUpdatedHours;
    mapping(uint8 => uint256) public ongoingTotals;

    // Here's the crux: rewards are aggregated hourly for ongoing incentive distribution
    // If e.g. a lender keeps their money in for several days, then their reward is going to be
    // amount * (reward_rate_hour1 + reward_rate_hour2 + reward_rate_hour3...)
    // where reward_rate is the amount of incentive per trade volume / lending volume
    mapping(uint8 => uint256) public aggregateHourlyRewardRate;
    mapping(uint256 => Claim) public claims;
    uint256 public nextClaimId;

    function getSpotReward(
        uint8 tranche,
        address recipient,
        uint256 amount
    ) external {
        // TODO auth role
        updateHourTotals(tranche);
        currentHourTotals[tranche] += amount;
        // TODO disburse
    }

    function updateHourTotals(uint8 tranche) internal {
        uint256 currentHour = (block.timestamp % (1 days)) / (1 hours);
        uint256 lastUpdatedHour = lastUpdatedHours[tranche];
        if (lastUpdatedHour != currentHour) {
            lastUpdatedHours[tranche] = currentHour;
            // This will skip hours if there has been no calls to this function in that tranche
            // In which case our rates are going to be somewhat out of whack anyway,
            // so we won't mind too much
            aggregateHourlyRewardRate[tranche] += currentHourlyRewardRate(
                tranche
            );
            currentDayTotals[tranche] -= hourlyTotals[tranche][lastUpdatedHour];
            hourlyTotals[tranche][lastUpdatedHour] = currentHourTotals[tranche];
            currentDayTotals[tranche] += hourlyTotals[tranche][lastUpdatedHour];
            currentHourTotals[tranche] = ongoingTotals[tranche];
            if (currentHour == 0) {
                currentDailyDistribution =
                    (currentDailyDistribution * contractionPerMil) /
                    1000;
            }
        }
    }

    function currentHourlyRewardRate(uint8 tranche) internal returns (uint256) {
        uint256 trancheDailyDistribution =
            (currentDailyDistribution * tranchePercentShare[tranche]) / 100;
        return trancheDailyDistribution / currentDayTotals[tranche] / 24;
    }

    function startClaim(
        uint8 tranche,
        address recipient,
        uint256 claimAmount
    ) external returns (uint256) {
        // TODO test authorization
        ongoingTotals[tranche] += claimAmount;
        currentHourTotals[tranche] += claimAmount;
        claims[nextClaimId] = Claim({
            startingRewardRate: aggregateHourlyRewardRate[tranche],
            recipient: recipient,
            amount: claimAmount
        });
        nextClaimId += 1;
        return nextClaimId - 1;
    }

    function endClaim(uint8 tranche, uint256 claimId) external {
        Claim storage claim = claims[claimId];
        // TODO what if empty?
        uint256 rewardAmount =
            claim.amount *
                (aggregateHourlyRewardRate[tranche] - claim.startingRewardRate);
        // TODO send
        delete claim.recipient;
    }
}
