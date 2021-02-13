import './Roles.sol';

contract RoleAware {
    // TODO enum?
    uint8 constant FUND_CHARACTER = 1;
    uint8 constant LENDING_CHARACTER = 2;
    uint8 constant ROUTER_CHARACTER = 3;
    uint8 constant MARGIN_TRADING = 4;
    uint8 constant FEE_CONTROLLER = 5;
    uint8 constant PRICE_CONTROLLER = 6;

    uint8 constant MTRADER_ROLE = 101;
    uint8 constant WITHDRAWER_ROLE = 102;
    uint8 constant MARGIN_CALLER_ROLE = 103;
    uint8 constant BORROWER_ROLE = 104;
    uint8 constant MARGIN_TRADER_ROLE = 105;
    uint8 constant FEE_SOURCE = 106;
    uint8 constant INSURANCE_CLAIMANT = 107;

    Roles public roles;
    constructor(address _roles) {
        roles = Roles(_roles);
    }

    function fund() internal view returns (address) {
        return roles.mainCharacters(FUND_CHARACTER);
    }

    function lending() internal view returns (address) {
        return roles.mainCharacters(LENDING_CHARACTER);
    }

    function router() internal view returns (address) {
        return roles.mainCharacters(ROUTER_CHARACTER);
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
        return roles.getRole(contr, BORROWER_ROLE);
    }

    function isWithdrawer(address contr) internal view returns (bool) {
        return roles.getRole(contr, WITHDRAWER_ROLE);
    }

    function isMarginTrader(address contr) internal view returns (bool) {
        return roles.getRole(contr, MARGIN_TRADER_ROLE);
    }

    function isFeeSource(address contr) internal view returns (bool) {
        return roles.getRole(contr, FEE_SOURCE);
    }

    function isMarginCaller(address contr) internal view returns (bool) {
        return roles.getRole(contr, MARGIN_CALLER_ROLE);
    }

    function isInsuranceClaimant(address contr) internal view returns (bool) {
        return roles.getRole(contr, INSURANCE_CLAIMANT);
    }
}
