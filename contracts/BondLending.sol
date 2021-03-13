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

abstract contract BondLending is BaseLending {
    // CAUTION: minRuntime must be at least 1 hour
    uint256 public minRuntime;
    uint256 public maxRuntime;
    uint256 public diffMaxMinRuntime;
    // this is the numerator under runtimeWeights.
    // any excess left over is the weight of hourly bonds
    uint256 public weightTotal;
    uint256 public borrowingMarkupFP;

    mapping(address => uint256[]) public maxYield;
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
                totalLending[token] += interpolatedAmount;
                totalLendingPerRuntime[token][
                    bucketIndex
                ] += interpolatedAmount;
                // TODO overflow??
                totalHourlyYieldFP[token] +=
                    (amount * yieldFP * (1 hours)) /
                    runtime;
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
        totalLending[token] -= interpolatedAmount;
        totalLendingPerRuntime[token][bucketIndex] -= interpolatedAmount;

        updateSpeed(
            withdrawingSpeed[token],
            lastWithdrawn[token],
            bucketIndex,
            bond.originalPrice
        );

        if (
            totalBorrowed[token] > totalLending[token] ||
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

    // TODO make sure yield changes can't get stuck under some circumstances
    function calcBondYieldFP(
        address token,
        uint256 totalLendingInBucket,
        uint256 bucketIndex
    ) internal view returns (uint256 yieldFP) {
        yieldFP = runtimeYieldsFP[token][bucketIndex];
        uint256 lastUpdated = yieldLastUpdated[token][bucketIndex];
        uint256 bucketTarget =
            (lendingTarget[token] * runtimeWeights[token][bucketIndex]) /
                weightTotal;
        uint256 buying = buyingSpeed[token][bucketIndex];
        uint256 withdrawing = withdrawingSpeed[token][bucketIndex];
        uint256 bucketMaxYield = maxYield[token][bucketIndex];

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

    function getAvgLendingYieldFP(address token)
        internal
        view
        returns (uint256)
    {
        return totalHourlyYieldFP[token] / totalLending[token];
    }

    function getHourlyBorrowYieldFP(address token)
        internal
        view
        returns (uint256)
    {
        return (getAvgLendingYieldFP(token) * borrowingMarkupFP) / FP32;
    }

    function getBucketIndex(address token, uint256 runtime)
        internal
        view
        returns (uint256 bucketIndex)
    {
        uint256[] storage yieldsFP = runtimeYieldsFP[token];
        uint256 bucketSize = diffMaxMinRuntime / yieldsFP.length;
        bucketIndex = runtime / bucketSize;
    }

    function updateSpeed(
        uint256[] storage speedRegister,
        uint256[] storage lastAction,
        uint256 bucketIndex,
        uint256 amount
    ) internal {
        uint256 bucketSize = diffMaxMinRuntime / speedRegister.length;
        uint256 runtime = bucketSize * bucketIndex;
        uint256 timeDiff = block.timestamp - lastAction[bucketIndex];
        uint256 currentSpeed = (amount * runtime) / (timeDiff + 1);

        // TODO init speed with runtime
        uint256 runtimeScale = runtime / (10 minutes);
        // scale adjustment relative to runtime
        speedRegister[bucketIndex] =
            (speedRegister[bucketIndex] * runtimeScale + currentSpeed * timeDiff) /
            (runtimeScale + timeDiff);
        lastAction[bucketIndex] = block.timestamp;
    }
}
