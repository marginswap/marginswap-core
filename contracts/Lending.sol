import "./RoleAware.sol";
import "./Fund.sol";

struct YieldAccumulator {
    uint256 accumulatorFP;
    uint256 lastUpdated;
    uint256 hourlyRateFP;
}

struct HourlyBondAccount {
    mapping(address => uint256) bonds;
    mapping(address => uint256) bondYieldQuotientsFP;
    uint256 moduloHour;
}

contract Lending is RoleAware, Ownable {
    uint256 constant FP32 = 2**32;
    uint256 constant ACCUMULATOR_INIT = 10**18;
    uint256 constant WITHDRAWAL_WINDOW = 6 minutes;
    mapping(address => uint256) public totalBorrowed;
    mapping(address => uint256) public totalHourlyBond;
    mapping(address => uint256) public totalSpotLending;

    mapping(address => HourlyBondAccount) public hourlyBondAccounts;
    mapping(address => YieldAccumulator) public hourlyBondYieldAccumulators;

    mapping(address => YieldAccumulator) public borrowYieldAccumulators;

    // token => end-day => yield
    mapping(address => mapping(uint256 => uint256)) public bondYieldFP;

    // token => end-day => portion of total target lending
    mapping(address => mapping(uint256 => uint256)) public bondTargetNumerator;
    // The totality by which we divide above targets
    uint256 public bondTotalTargetQuotient;

    // TODO replace with function
    uint256 public bondTotalDailyTarget;
    mapping(uint256 => uint256) public dailyMaturing;

    constructor(address _roles) RoleAware(_roles) Ownable() {}

    function getUpdatedRate(address token, uint256 runtime) external {
        uint256 supply;
        uint256 demand;
        uint256 rate;

        //uint timeDelta = block.timestamp - lastUpdated;
        //uint rateUpdateNumerator = (demand + reserve) * rate / supply;
        //uint rateUpdateQuotient =
    }

    function buyHourlyBondSubscription(address token, uint256 amount) external {
        HourlyBondAccount storage account = hourlyBondAccounts[msg.sender];
        uint256 yieldQuotient = account.bondYieldQuotientsFP[token];
        if (yieldQuotient > 0) {
            YieldAccumulator storage yA =
                getUpdatedCumulativeYield(
                    token,
                    hourlyBondYieldAccumulators,
                    block.timestamp
                );

            account.bonds[token] = applyInterest(
                account.bonds[token],
                yA.accumulatorFP,
                account.bondYieldQuotientsFP[token]
            );
        }
        account.bondYieldQuotientsFP[token] = hourlyBondYieldAccumulators[token]
            .accumulatorFP;
        account.moduloHour = block.timestamp % (1 hours);
        require(
            Fund(fund()).deposit(token, amount),
            "Could not transfer bond deposit token to fund"
        );
        account.bonds[token] += amount;
        totalHourlyBond[token] += amount;
    }

    function applyInterest(
        uint256 balance,
        uint256 accumulatorFP,
        uint256 yieldQuotientFP
    ) internal pure returns (uint256) {
        // 1 * FP / FP = 1
        return (balance * accumulatorFP) / yieldQuotientFP;
    }

    function applyBorrowInterest(
        uint256 balance,
        address token,
        uint256 yieldQuotientFP
    ) external returns (uint256) {
        YieldAccumulator storage yA =
            getUpdatedCumulativeYield(
                token,
                borrowYieldAccumulators,
                block.timestamp
            );
        return applyInterest(balance, yA.accumulatorFP, yieldQuotientFP);
    }

    function viewBorrowInterest(
        uint256 balance,
        address token,
        uint256 yieldQuotientFP
    ) external view returns (uint256) {
        uint256 accumulatorFP =
            viewCumulativeYield(
                token,
                borrowYieldAccumulators,
                block.timestamp
            );
        return applyInterest(balance, accumulatorFP, yieldQuotientFP);
    }

    function withdrawHourlyBonds(address token, uint256 amount) external {
        HourlyBondAccount storage account = hourlyBondAccounts[msg.sender];
        // how far the current hour has advanced (relative to acccount hourly clock)
        uint256 currentOffset =
            (block.timestamp - account.moduloHour) % (1 hours);

        require(
            WITHDRAWAL_WINDOW >= currentOffset,
            "Tried withdrawing outside subscription cancellation time window"
        );
        require(
            Fund(fund()).withdraw(token, msg.sender, amount),
            "Insufficient liquidity"
        );

        account.bonds[token] -= amount;
        totalHourlyBond[token] -= amount;
    }

    function registerBorrow(address token, uint256 amount) external {
        require(isBorrower(msg.sender), "Not an approved borrower");
        require(Fund(fund()).activeTokens(token), "Not an approved token");
        totalBorrowed[token] += amount;
        require(
            totalHourlyBond[token] + totalSpotLending[token] >=
                totalBorrowed[token],
            "Insufficient capital to lend"
        );
    }

    function payOff(address token, uint256 amount) external {
        require(isBorrower(msg.sender), "Not an approved borrower");
        totalBorrowed[token] -= amount;
    }

    function calcCumulativeYield(
        YieldAccumulator storage yieldAccumulator,
        uint256 timeDelta
    ) internal view returns (uint256 accumulatorFP) {
        uint256 secondsDelta = timeDelta % (1 hours);
        // linearly interpolate interest for seconds
        // accumulator * hourly_rate == seconds_per_hour * accumulator * hourly_rate / seconds_per_hour
        // FP * FP * 1 / (FP * 1) = FP
        accumulatorFP =
            (yieldAccumulator.accumulatorFP *
                (FP32 + yieldAccumulator.hourlyRateFP) *
                secondsDelta) /
            (FP32 * 1 hours);

        uint256 hoursDelta = timeDelta / (1 hours);
        if (hoursDelta > 0) {
            // This loop should hardly ever 1 or more unless something bad happened
            // In which case it costs gas but there isn't overflow
            for (uint256 i = 0; hoursDelta > i; i++) {
                // FP32 * FP32 / FP32 = FP32
                accumulatorFP =
                    (accumulatorFP * (FP32 + yieldAccumulator.hourlyRateFP)) /
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
        uint256 timeDelta = (timestamp - yieldAccumulators[token].lastUpdated);
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

    function viewBorrowingYield(address token) external view returns (uint256) {
        return
            viewCumulativeYield(
                token,
                borrowYieldAccumulators,
                block.timestamp
            );
    }
}
