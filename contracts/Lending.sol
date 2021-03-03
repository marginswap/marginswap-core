// SPDX-License-Identifier: GPL-2.0-only
pragma solidity ^0.8.0;

import "./Fund.sol";
import "./HourlyBondSubscriptionLending.sol";
import "./BondLending.sol";

contract Lending is BaseLending, HourlyBondSubscriptionLending, BondLending {
    mapping(address => YieldAccumulator) public borrowYieldAccumulators;

    constructor(address _roles) RoleAware(_roles) Ownable() {}

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

    function registerBorrow(address token, uint256 amount) external {
        require(isBorrower(msg.sender), "Not an approved borrower");
        require(Fund(fund()).activeTokens(token), "Not an approved token");
        totalBorrowed[token] += amount;
        require(
            totalLending[token] >= totalBorrowed[token],
            "Insufficient capital to lend, try again later!"
        );
    }

    function payOff(address token, uint256 amount) external {
        require(isBorrower(msg.sender), "Not an approved borrower");
        totalBorrowed[token] -= amount;
    }

    function viewBorrowingYield(address token) external view returns (uint256) {
        return
            viewCumulativeYield(
                token,
                borrowYieldAccumulators,
                block.timestamp
            );
    }

    function _makeFallbackBond(
        address token,
        address holder,
        uint256 amount
    ) internal override {
        _makeHourlyBond(token, holder, amount);
    }
}
