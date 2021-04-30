// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;
import "./RoleAware.sol";
import "./Lending.sol";
import "./PriceAware.sol";

abstract contract IsolatedMarginAccounts is RoleAware {
    struct IsolatedMarginAccount {
        uint256 lastDepositBlock;
        uint256 borrowed;
        uint256 borrowedYieldQuotientFP;
        uint256 holding;
    }

    address public borrowToken;
    address public holdingToken;

    bytes32 public amms;
    address[] public liquidationTokens;

    /// @dev percentage of assets held per assets borrowed at which to liquidate
    uint256 public liquidationThresholdPercent = 115;

    mapping(address => IsolatedMarginAccount) public marginAccounts;
    uint256 public coolingOffPeriod = 20;
    uint256 public leveragePercent = 500;

    /// @dev adjust account to reflect borrowing of token amount
    function borrow(IsolatedMarginAccount storage account, uint256 amount)
        internal
    {
        updateLoan(account);
        account.borrowed += amount;
        require(positiveBalance(account), "Can't borrow: insufficient balance");
    }

    function updateLoan(IsolatedMarginAccount storage account) internal {
        (account.borrowed, account.borrowedYieldQuotientFP) = Lending(lending())
            .applyBorrowInterest(
            account.borrowed,
            address(this),
            account.borrowedYieldQuotientFP
        );
    }

    /// @dev checks whether account is in the black, deposit + earnings relative to borrowed
    function positiveBalance(IsolatedMarginAccount storage account)
        internal
        returns (bool)
    {
        uint256 loan = loanInPeg(account);
        uint256 holdings = holdingInPeg(account);

        // The following condition should hold:
        // holdings / loan >= leveragePercent / (leveragePercent - 100)
        // =>
        return holdings * (leveragePercent - 100) >= loan * leveragePercent;
    }

    /// @dev internal function adjusting holding and borrow balances when debt extinguished
    function extinguishDebt(
        IsolatedMarginAccount storage account,
        uint256 extinguishAmount
    ) internal {
        // TODO check if underflow?
        // TODO TELL LENDING
        updateLoan(account);
        account.borrowed -= extinguishAmount;
    }

    /// @dev check whether an account can/should be liquidated
    function belowMaintenanceThreshold(IsolatedMarginAccount storage account)
        internal
        returns (bool)
    {
        uint256 loan = loanInPeg(account);
        uint256 holdings = holdingInPeg(account);
        // The following should hold:
        // holdings / loan >= 1.1
        // => holdings >= loan * 1.1
        return 100 * holdings < liquidationThresholdPercent * loan;
    }

    /// @dev calculate loan in reference currency
    function loanInPeg(IsolatedMarginAccount storage account)
        internal
        returns (uint256)
    {
        return
            PriceAware(price()).getCurrentPriceInPeg(
                borrowToken,
                account.borrowed,
                false
            );
    }

    /// @dev calculate loan in reference currency
    function holdingInPeg(IsolatedMarginAccount storage account)
        internal
        returns (uint256)
    {
        return
            PriceAware(price()).getCurrentPriceInPeg(
                holdingToken,
                account.holding,
                false
            );
    }

    /// @dev minimum
    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a > b) {
            return b;
        } else {
            return a;
        }
    }
}
