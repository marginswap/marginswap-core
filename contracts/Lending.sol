// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "./Fund.sol";
import "./HourlyBondSubscriptionLending.sol";
import "./BondLending.sol";
import "./IncentivizedHolder.sol";

/// @title Manage lending
contract Lending is
    BaseLending,
    HourlyBondSubscriptionLending,
    BondLending,
    IncentivizedHolder
{
    /// @dev IDs for all bonds held by an address
    mapping(address => uint256[]) public bondIds;

    constructor(address _roles) RoleAware(_roles) Ownable() {
        uint256 APR = 899;
        maxHourlyYieldFP = (FP32 * APR) / 100 / (24 * 365);

        uint256 aprChangePerMil = 3;
        yieldChangePerSecondFP = (FP32 * aprChangePerMil) / 1000;
    }

    /// @dev how much interest has accrued to a borrowed balance over time
    function applyBorrowInterest(
        uint256 balance,
        address token,
        uint256 yieldQuotientFP
    ) external returns (uint256 balanceWithInterest) {
        require(isBorrower(msg.sender), "Not an approved borrower");

        YieldAccumulator storage yA = borrowYieldAccumulators[token];
        balanceWithInterest = applyInterest(
            balance,
            yA.accumulatorFP,
            yieldQuotientFP
        );

        uint256 deltaAmount = balanceWithInterest - balance;
        LendingMetadata storage meta = lendingMeta[token];
        meta.totalBorrowed += deltaAmount;
    }

    /// @dev view function to get current borrowing interest
    function viewBorrowInterest(
        uint256 balance,
        address token,
        uint256 yieldQuotientFP
    ) external view returns (uint256) {
        uint256 accumulatorFP =
            viewCumulativeYieldFP(
                borrowYieldAccumulators[token],
                block.timestamp
            );
        return applyInterest(balance, accumulatorFP, yieldQuotientFP);
    }

    /// @dev gets called by router to register if a trader borrows tokens
    function registerBorrow(address token, uint256 amount) external {
        require(isBorrower(msg.sender), "Not an approved borrower");
        require(Fund(fund()).activeTokens(token), "Not an approved token");
        LendingMetadata storage meta = lendingMeta[token];
        meta.totalBorrowed += amount;
        require(
            meta.totalLending >= meta.totalBorrowed,
            "Insufficient capital to lend, try again later!"
        );
    }

    /// @dev gets called by router if loan is extinguished
    function payOff(address token, uint256 amount) external {
        require(isBorrower(msg.sender), "Not an approved borrower");
        lendingMeta[token].totalBorrowed -= amount;
    }

    /// @dev get the borrow yield
    function viewBorrowingYieldFP(address token)
        external
        view
        returns (uint256)
    {
        return
            viewCumulativeYieldFP(
                borrowYieldAccumulators[token],
                block.timestamp
            );
    }

    /// @dev In a liquidity crunch make a fallback bond until liquidity is good again
    function _makeFallbackBond(
        address token,
        address holder,
        uint256 amount
    ) internal override {
        _makeHourlyBond(token, holder, amount);
    }

    /// @dev withdraw an hour bond
    function withdrawHourlyBond(address token, uint256 amount) external {
        HourlyBond storage bond = hourlyBondAccounts[token][msg.sender];
        // apply all interest
        updateHourlyBondAmount(token, bond);
        super._withdrawHourlyBond(token, bond, msg.sender, amount);

        withdrawClaim(msg.sender, token, amount);
    }

    /// @dev buy hourly bond subscription
    function buyHourlyBondSubscription(address token, uint256 amount) external {
        LendingMetadata storage meta = lendingMeta[token];
        if (lendingTarget(meta) >= meta.totalLending + amount) {
            Fund(fund()).depositFor(msg.sender, token, amount);

            super._makeHourlyBond(token, msg.sender, amount);

            stakeClaim(msg.sender, token, amount);
        }
    }

    /// @dev buy fixed term bond that does not renew
    function buyBond(
        address token,
        uint256 runtime,
        uint256 amount,
        uint256 minReturn
    ) external returns (uint256 bondIndex) {
        LendingMetadata storage meta = lendingMeta[token];
        if (
            lendingTarget(meta) >= meta.totalLending + amount &&
            maxRuntime >= runtime &&
            runtime >= minRuntime
        ) {
            bondIndex = super._makeBond(
                msg.sender,
                token,
                runtime,
                amount,
                minReturn
            );
            if (bondIndex > 0) {
                bondIds[msg.sender].push(bondIndex);

                stakeClaim(msg.sender, token, amount);
            }
        }
    }

    /// @dev send back funds of bond after maturity
    function withdrawBond(uint256 bondId) external {
        Bond storage bond = bonds[bondId];
        require(msg.sender == bond.holder, "Not holder of bond");
        require(
            block.timestamp > bond.maturityTimestamp,
            "bond is still immature"
        );
        // in case of a shortfall, governance can step in to provide
        // additonal compensation beyond the usual incentive which
        // gets withdrawn here
        withdrawClaim(msg.sender, bond.token, bond.originalPrice);

        super._withdrawBond(bondId, bond);
    }

    function initBorrowYieldAccumulator(address token) external {
        require(
            isTokenActivator(msg.sender),
            "not autorized to init yield accumulator"
        );
        require(
            borrowYieldAccumulators[token].accumulatorFP == 0,
            "trying to re-initialize yield accumulator"
        );

        borrowYieldAccumulators[token].accumulatorFP = FP32;
    }

    function setBorrowingFactorPercent(uint256 borrowingFactor)
        external
        onlyOwner
    {
        borrowingFactorPercent = borrowingFactor;
    }
}
