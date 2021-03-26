// SPDX-License-Identifier: GPL-2.0-only
pragma solidity ^0.8.0;
import "./BaseLending.sol";
import "./Fund.sol";

struct Bond {
    address holder;
    address token;
    uint256 originalPrice;
    uint256 returnAmount;
    uint256 maturityTimestamp;
    uint256 runtime;
    uint256 yieldFP;
}

/// @dev Lending for fixed runtime, fixed interest
/// Lenders can pick their own bond maturity date --
/// In order to manage interest rates for the different
/// maturities and create a yield curve we bucket
/// bond runtimes into weighted baskets and adjust
/// rates individually per bucket, based on supply and demand.
abstract contract BondLending is BaseLending {
    uint256 public minRuntime = 30 days;
    uint256 public maxRuntime = 365 days;
    uint256 public diffMaxMinRuntime;
    // this is the numerator under runtimeWeights.
    // any excess left over is the weight of hourly bonds
    uint256 public constant WEIGHT_TOTAL_10k = 10_000;
    uint256 public borrowingMarkupFP;

    mapping(address => uint256[]) public runtimeWeights;
    mapping(address => uint256[]) public buyingSpeed;
    mapping(address => uint256[]) public lastBought;
    mapping(address => uint256[]) public withdrawingSpeed;
    mapping(address => uint256[]) public lastWithdrawn;
    mapping(address => uint256[]) public yieldLastUpdated;

    mapping(uint256 => Bond) public bonds;

    mapping(address => uint256[]) public totalLendingPerRuntime;
    mapping(address => uint256[]) runtimeYieldsFP;
    uint256 public nextBondIndex = 1;

    event LiquidityWarning(
        address indexed token,
        address indexed holder,
        uint256 value
    );

    function _makeBond(
        address holder,
        address token,
        uint256 runtime,
        uint256 amount,
        uint256 minReturn
    ) internal returns (uint256 bondIndex) {
        uint256 bucketIndex = getBucketIndex(token, runtime);
        uint256 yieldFP =
            calcBondYieldFP(
                token,
                amount + totalLendingPerRuntime[token][bucketIndex],
                bucketIndex
            );
        uint256 bondReturn = (yieldFP * amount) / FP32;
        if (bondReturn >= minReturn) {
            if (Fund(fund()).depositFor(holder, token, amount)) {
                uint256 interpolatedAmount = (amount + bondReturn) / 2;
                lendingMeta[token].totalLending += interpolatedAmount;

                totalLendingPerRuntime[token][
                    bucketIndex
                ] += interpolatedAmount;

                bondIndex = nextBondIndex;
                nextBondIndex++;

                bonds[bondIndex] = Bond({
                    holder: holder,
                    token: token,
                    originalPrice: amount,
                    returnAmount: bondReturn,
                    maturityTimestamp: block.timestamp + runtime,
                    runtime: runtime,
                    yieldFP: yieldFP
                });

                updateSpeed(
                    buyingSpeed[token],
                    lastBought[token],
                    bucketIndex,
                    amount
                );
            }
        }
    }

    function _withdrawBond(Bond storage bond) internal {
        address token = bond.token;
        uint256 bucketIndex = getBucketIndex(token, bond.runtime);
        uint256 interpolatedAmount =
            (bond.originalPrice + bond.returnAmount) / 2;

        LendingMetadata storage meta = lendingMeta[token];
        meta.totalLending -= interpolatedAmount;
        totalLendingPerRuntime[token][bucketIndex] -= interpolatedAmount;

        updateSpeed(
            withdrawingSpeed[token],
            lastWithdrawn[token],
            bucketIndex,
            bond.originalPrice
        );

        if (
            meta.totalBorrowed > meta.totalLending ||
            !Fund(fund()).withdraw(token, bond.holder, bond.returnAmount)
        ) {
            // apparently there is a liquidity issue
            emit LiquidityWarning(token, bond.holder, bond.returnAmount);
            _makeFallbackBond(token, bond.holder, bond.returnAmount);
        }
    }

    function getUpdatedBondYieldFP(
        address token,
        uint256 runtime,
        uint256 amount
    ) internal returns (uint256 yieldFP, uint256 bucketIndex) {
        bucketIndex = getBucketIndex(token, runtime);
        yieldFP = calcBondYieldFP(
            token,
            amount + totalLendingPerRuntime[token][bucketIndex],
            bucketIndex
        );
        runtimeYieldsFP[token][bucketIndex] = yieldFP;
        yieldLastUpdated[token][bucketIndex] = block.timestamp;
    }

    function calcBondYieldFP(
        address token,
        uint256 totalLendingInBucket,
        uint256 bucketIndex
    ) internal view returns (uint256 yieldFP) {
        yieldFP = runtimeYieldsFP[token][bucketIndex];
        uint256 lastUpdated = yieldLastUpdated[token][bucketIndex];

        LendingMetadata storage meta = lendingMeta[token];
        uint256 bucketTarget =
            (lendingTarget(meta) * runtimeWeights[token][bucketIndex]) /
                WEIGHT_TOTAL_10k;

        uint256 buying = buyingSpeed[token][bucketIndex];
        uint256 withdrawing = withdrawingSpeed[token][bucketIndex];

        uint256 runtime = minRuntime + bucketIndex * diffMaxMinRuntime;
        uint256 bucketMaxYield = maxHourlyYieldFP * (runtime / (1 hours));

        yieldFP = updatedYieldFP(
            yieldFP,
            lastUpdated,
            totalLendingInBucket,
            bucketTarget,
            buying,
            withdrawing,
            bucketMaxYield
        );
    }

    function viewBondReturn(
        address token,
        uint256 runtime,
        uint256 amount
    ) external view returns (uint256) {
        uint256 bucketIndex = getBucketIndex(token, runtime);
        uint256 yieldFP =
            calcBondYieldFP(
                token,
                amount + totalLendingPerRuntime[token][bucketIndex],
                bucketIndex
            );
        return (yieldFP * amount) / FP32;
    }

    function getBucketIndex(address token, uint256 runtime)
        internal
        view
        returns (uint256 bucketIndex)
    {
        uint256[] storage yieldsFP = runtimeYieldsFP[token];
        uint256 bucketSize = diffMaxMinRuntime / yieldsFP.length;
        bucketIndex = (runtime - minRuntime) / bucketSize;
    }

    function updateSpeed(
        uint256[] storage speedRegister,
        uint256[] storage lastAction,
        uint256 bucketIndex,
        uint256 amount
    ) internal {
        uint256 bucketSize = diffMaxMinRuntime / speedRegister.length;
        uint256 runtime = minRuntime + bucketSize * bucketIndex;
        uint256 timeDiff = block.timestamp - lastAction[bucketIndex];
        uint256 currentSpeed = (amount * runtime) / (timeDiff + 1);

        uint256 runtimeScale = runtime / (10 minutes);
        // scale adjustment relative togit  runtime
        speedRegister[bucketIndex] =
            (speedRegister[bucketIndex] *
                runtimeScale +
                currentSpeed *
                timeDiff) /
            (runtimeScale + timeDiff);
        lastAction[bucketIndex] = block.timestamp;
    }

    function setRuntimeYieldsFP(address token, uint256[] memory yieldsFP)
        external
        onlyOwner
    {
        runtimeYieldsFP[token] = yieldsFP;
    }

    function setRuntimeWeights(address token, uint256[] memory weights)
        external
    {
        require(
            isTokenActivator(msg.sender),
            "not autorized to set runtime weights"
        );
        require(
            runtimeWeights[token].length == 0 ||
                runtimeWeights[token].length == weights.length,
            "Cannot change size of weight array"
        );
        if (runtimeWeights[token].length == 0) {
            // we are initializing

            runtimeYieldsFP[token] = new uint256[](weights.length);
            lastBought[token] = new uint256[](weights.length);
            lastWithdrawn[token] = new uint256[](weights.length);
            yieldLastUpdated[token] = new uint256[](weights.length);
            buyingSpeed[token] = new uint256[](weights.length);
            withdrawingSpeed[token] = new uint256[](weights.length);

            uint256 hourlyYieldFP = (110 * FP32) / 100 / (24 * 365);
            uint256 bucketSize = diffMaxMinRuntime / weights.length;

            for (uint256 i = 0; weights.length > i; i++) {
                uint256 runtime = minRuntime + bucketSize * i;
                // Do a best guess of initializing
                runtimeYieldsFP[token][i] =
                    hourlyYieldFP *
                    (runtime / (1 hours));

                lastBought[token][i] = block.timestamp;
                lastWithdrawn[token][i] = block.timestamp;
                yieldLastUpdated[token][i] = block.timestamp;
            }
        }

        runtimeWeights[token] = weights;
    }

    function setMinRuntime(uint256 runtime) external onlyOwner {
        require(runtime > 1 hours, "Min runtime needs to be at least 1 hour");
        require(maxRuntime > runtime, "Min runtime must be smaller than max runtime");
        minRuntime = runtime;
    }

    function setMaxRuntime(uint256 runtime) external onlyOwner {
        require(
            runtime > minRuntime,
            "Max runtime must be greater than min runtime"
        );
        maxRuntime = runtime;
    }
}
