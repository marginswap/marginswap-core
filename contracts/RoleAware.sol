import './Roles.sol';

contract RoleAware {
    uint8 constant FUND_CHARACTER = 1;
    uint8 constant LENDING_CHARACTER = 2;
    uint8 constant ROUTER_CHARACTER = 3;

    uint8 constant MTRADER_ROLE = 101;
    uint8 constant WITHDRAWER_ROLE = 102;
    uint8 constant MARGIN_CALLER_ROLE = 103;
    uint8 constant BORROWER_ROLE = 104;
    uint8 constant MARGIN_TRADER_ROLE = 105;

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

    function isBorrower(address contr) internal view returns (bool) {
        return roles.getRole(contr, BORROWER_ROLE);
    }

    function isWithdrawer(address contr) internal view returns (bool) {
        return roles.getRole(contr, WITHDRAWER_ROLE);
    }

    function isMarginTrader(address contr) internal view returns (bool) {
        return roles.getRole(contr, MARGIN_TRADER_ROLE);
    }
}
