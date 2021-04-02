// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;
import "./RoleAware.sol";
import "./Lending.sol";
import "./CrossMarginTrading.sol";

/// @title anyone can call this contract to update relending levels
contract Relender is RoleAware, Ownable {
    uint256 public relendPercent = 10;

    constructor(address _roles) RoleAware(_roles) Ownable() {}

    function setRelendPercent(uint256 newRelendPercent) external onlyOwner {
        relendPercent = newRelendPercent;
    }

    /// @dev relend from cross margin holdings
    function crossRelend(address token) external {
        uint256 relendBalance =
            Lending(lending()).viewHourlyBondAmount(token, address(this));
        uint256 relendTarget =
            CrossMarginTrading(marginTrading()).totalLong(token);
        if (relendBalance > relendTarget) {
            Lending(lending()).withdrawHourlyBond(
                token,
                relendBalance - relendTarget
            );
        } else {
            Lending(lending()).buyHourlyBondSubscription(
                token,
                relendTarget - relendBalance
            );
        }
    }
}
