import './RoleAware.sol';
import './Fund.sol';

struct YieldAccumulator {
    uint accumulatorFP;
    uint lastUpdated;
    uint hourlyRateFP;
}

struct HourlyBondAccount {
    mapping(address => uint) bonds;
    mapping(address => uint) bondYieldQuotientsFP;
    uint moduloHour;
}

contract Lending is RoleAware {
    uint constant FP32 = 2 ** 32;
    uint constant ACCUMULATOR_INIT = 10 ** 18;
    uint constant WITHDRAWAL_WINDOW = 6 minutes;
    mapping(address => uint) public totalBorrowed;
    mapping(address => uint) public totalHourlyBond;
    mapping(address => uint) public totalSpotLending;

    mapping(address => HourlyBondAccount) public hourlyBondAccounts;
    mapping(address => YieldAccumulator) public hourlyBondYieldAccumulators;

    mapping(address => YieldAccumulator) public borrowYieldAccumulators;

    // token => end-day => yield
    mapping(address => mapping(uint => uint)) public bondYieldFP;

    // token => end-day => portion of total target lending
    mapping(address => mapping(uint => uint)) public bondTargetNumerator;
    // The totality by which we divide above targets
    uint public bondTotalTargetQuotient;

    // TODO replace with function
    uint public bondTotalDailyTarget;
    mapping(uint => uint) public dailyMaturing;

    constructor( address _roles) RoleAware(_roles) {
    }

    function getUpdatedRate(address token, uint runtime) external {
        uint supply;
        uint demand;
        uint rate;

        //uint timeDelta = block.timestamp - lastUpdated;
        //uint rateUpdateNumerator = (demand + reserve) * rate / supply;
        //uint rateUpdateQuotient =  
    }

    function buyHourlyBondSubscription(address token, uint amount) external {
        HourlyBondAccount storage account = hourlyBondAccounts[msg.sender];
        uint yieldQuotient = account.bondYieldQuotientsFP[token];
        if (yieldQuotient > 0) {
            YieldAccumulator storage yA = getUpdatedCumulativeYield(token,
                                                                    hourlyBondYieldAccumulators,
                                                                    block.timestamp);

            account.bonds[token] = applyInterest(account.bonds[token],
                                                 yA.accumulatorFP,
                                                 account.bondYieldQuotientsFP[token]);
        }
        account.bondYieldQuotientsFP[token] = hourlyBondYieldAccumulators[token].accumulatorFP;
        account.moduloHour = block.timestamp % (1 hours);
        require(Fund(fund()).deposit(token, amount),
                "Could not transfer bond deposit token to fund");
        account.bonds[token] += amount;
        totalHourlyBond[token] += amount;
    }

    function applyInterest(uint balance, uint accumulatorFP, uint yieldQuotientFP) internal returns (uint) {
        // 1 * FP / FP = 1
        return balance * accumulatorFP / yieldQuotientFP;
    }

    function applyBorrowInterest(uint balance, address token, uint yieldQuotientFP)
        external returns (uint) {
        YieldAccumulator storage yA = getUpdatedCumulativeYield(token,
                                                                borrowYieldAccumulators,
                                                                block.timestamp);
        return applyInterest(balance, yA.accumulatorFP, yieldQuotientFP);
    }

    function withdrawHourlyBonds(address token, uint amount) external {
        HourlyBondAccount storage account = hourlyBondAccounts[msg.sender];
        // how far the current hour has advanced (relative to acccount hourly clock)
        uint currentOffset = (block.timestamp - account.moduloHour) % (1 hours);

        require(WITHDRAWAL_WINDOW >= currentOffset,
                "Tried withdrawing outside subscription cancellation time window");
        require(Fund(fund()).withdraw(token, msg.sender, amount),
                "Insufficient liquidity");

        account.bonds[token] -= amount;
        totalHourlyBond[token] -= amount;
    }
    
    function registerBorrow(address token, uint amount) external {
        require(isBorrower(msg.sender),
                "Not an approved borrower");
        require(Fund(fund()).activeTokens(token),
                "Not an approved token");
        totalBorrowed[token] += amount;
        require(totalHourlyBond[token] + totalSpotLending[token] >= totalBorrowed[token],
                "Insufficient capital to lend");
    }

    function payOff(address token, uint amount) external {
        require(isBorrower(msg.sender),
                "Not an approved borrower");
        totalBorrowed[token] -= amount;
    }

    function calcCumulativeYield(YieldAccumulator storage yieldAccumulator, uint timeDelta)
        internal view returns (uint accumulatorFP) {
        uint secondsDelta = timeDelta % (1 hours);
        // linearly interpolate interest for seconds
        // accumulator * hourly_rate == seconds_per_hour * accumulator * hourly_rate / seconds_per_hour
        // FP * FP * 1 / (FP * 1) = FP
        accumulatorFP = yieldAccumulator.accumulatorFP
            * (FP32 + yieldAccumulator.hourlyRateFP)
            * secondsDelta
            / (FP32 * 1 hours);

        uint hoursDelta = timeDelta / (1 hours);
        if (hoursDelta > 0) {
            // This loop should hardly ever 1 or more unless something bad happened
            // In which case it costs gas but there isn't overflow
            for (uint i = 0; hoursDelta > i; i ++) {
                // FP32 * FP32 / FP32 = FP32
                accumulatorFP = accumulatorFP * (FP32 + yieldAccumulator.hourlyRateFP) / FP32;
            }
        }
    }

    function getUpdatedCumulativeYield(address token,
                                       mapping(address => YieldAccumulator) storage yieldAccumulators,
                                       uint timestamp)
        internal returns (YieldAccumulator storage accumulator) {
        accumulator = yieldAccumulators[token];
        uint timeDelta = (timestamp - yieldAccumulators[token].lastUpdated);
        accumulator.accumulatorFP = calcCumulativeYield(accumulator, timeDelta);
    }

    function viewCumulativeYield(address token,
                                 mapping(address => YieldAccumulator) storage yieldAccumulators,
                                 uint timestamp)
        internal view returns (uint) {
        uint timeDelta = (timestamp - yieldAccumulators[token].lastUpdated);
        return calcCumulativeYield(yieldAccumulators[token], timeDelta);
    }

    function viewBorrowingYield(address token) external view returns (uint) {
        return viewCumulativeYield(token, borrowYieldAccumulators, block.timestamp);
    }
}
