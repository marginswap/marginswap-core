// SPDX-License-Identifier: GPL-2.0-only
pragma solidity ^0.8.0;

import "./Roles.sol";

contract RoleAware {
    uint16 public constant WITHDRAWER = 1;
    uint16 public constant MARGIN_CALLER = 2;
    uint16 public constant BORROWER = 3;
    uint16 public constant MARGIN_TRADER = 4;
    uint16 public constant FEE_SOURCE = 5;
    uint16 public constant LIQUIDATOR = 6;
    uint16 public constant AUTHORIZED_FUND_TRADER = 7;
    uint16 public constant INCENTIVE_REPORTER = 8;

    uint16 public constant FUND = 101;
    uint16 public constant LENDING = 102;
    uint16 public constant ROUTER = 103;
    uint16 public constant MARGIN_TRADING = 104;
    uint16 public constant FEE_CONTROLLER = 105;
    uint16 public constant PRICE_CONTROLLER = 106;

    Roles public roles;

    constructor(address _roles) {
        roles = Roles(_roles);
    }

    modifier noIntermediary() {
        require(
            msg.sender == tx.origin,
            "Currently no intermediaries allowed for this function call"
        );
        _;
    }

    function fund() internal view returns (address) {
        return roles.mainCharacters(FUND);
    }

    function lending() internal view returns (address) {
        return roles.mainCharacters(LENDING);
    }

    function router() internal view returns (address) {
        return roles.mainCharacters(ROUTER);
    }

    function marginTrading() internal view returns (address) {
        return roles.mainCharacters(MARGIN_TRADING);
    }

    function feeController() internal view returns (address) {
        return roles.mainCharacters(FEE_CONTROLLER);
    }

    function price() internal view returns (address) {
        return roles.mainCharacters(PRICE_CONTROLLER);
    }

    function isBorrower(address contr) internal view returns (bool) {
        return roles.getRole(contr, BORROWER);
    }

    function isWithdrawer(address contr) internal view returns (bool) {
        return roles.getRole(contr, WITHDRAWER);
    }

    function isMarginTrader(address contr) internal view returns (bool) {
        return roles.getRole(contr, MARGIN_TRADER);
    }

    function isFeeSource(address contr) internal view returns (bool) {
        return roles.getRole(contr, FEE_SOURCE);
    }

    function isMarginCaller(address contr) internal view returns (bool) {
        return roles.getRole(contr, MARGIN_CALLER);
    }

    function isLiquidator(address contr) internal view returns (bool) {
        return roles.getRole(contr, LIQUIDATOR);
    }

    function isAuthorizedFundTrader(address contr)
        internal
        view
        returns (bool)
    {
        return roles.getRole(contr, AUTHORIZED_FUND_TRADER);
    }

    function isIncentiveReporter(address contr) internal view returns (bool) {
        return roles.getRole(contr, INCENTIVE_REPORTER);
    }
}
