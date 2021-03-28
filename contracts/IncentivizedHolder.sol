// SPDX-License-Identifier: GPL-2.0-only
pragma solidity ^0.8.0;

import "./IncentiveDistribution.sol";
import "./RoleAware.sol";

/// @dev helper class to facilitate staking and unstaking
/// within the incentive system.
abstract contract IncentivizedHolder is RoleAware {
    // here we cache incentive tranches to save on a bit of gas
    mapping(address => uint8) public incentiveTranches;
    // claimant => token => claimId
    mapping(address => mapping(address => uint256)) public claimIds;

    function setIncentiveTranche(address token, uint8 tranche) external {
        require(
            isTokenActivator(msg.sender),
            "Caller not authorized to set incentive tranche"
        );
        incentiveTranches[token] = tranche;
    }

    function stakeClaim(
        address claimant,
        address token,
        uint256 amount
    ) internal {
        IncentiveDistribution iD =
            IncentiveDistribution(incentiveDistributor());
        uint256 claimId = claimIds[claimant][token];
        uint8 tranche = incentiveTranches[token];
        if (claimId > 0) {
            iD.addToClaimAmount(tranche, claimId, amount);
        } else {
            claimId = iD.startClaim(tranche, claimant, amount);

            // check that distribution hasn't ended yet
            if(claimId > 0) {
                claimIds[claimant][token] = claimId;
            }
        }
    }

    function withdrawClaim(
        address claimant,
        address token,
        uint256 amount
    ) internal {
        uint256 claimId = claimIds[claimant][token];
        if (claimId > 0) {
            uint8 tranche = incentiveTranches[token];
            // this does not end claims if they zero out, but we are willing
            // to sacrifice the gas refund from zeroing out for simplicity
            // sake and saving storage cost wwhen starting a claim
            IncentiveDistribution(incentiveDistributor()).subtractFromClaimAmount(
                tranche,
                claimId,
                amount
            );
        }
    }

    function endClaim(address claimant, address token) internal {
        uint256 claimId = claimIds[claimant][token];
        uint8 tranche = incentiveTranches[token];
        IncentiveDistribution(incentiveDistributor()).endClaim(tranche, claimId);
        claimIds[claimant][token] = 0;
    }
}
