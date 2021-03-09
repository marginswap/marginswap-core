// SPDX-License-Identifier: GPL-2.0-only
pragma solidity ^0.8.0;

import "./RoleAware.sol";
import "./IncentiveDistribution.sol";
import "./Fund.sol";
import "./CrossMarginTrading.sol";

contract TokenAdmin is RoleAware, Ownable {
    uint256 public totalLendingTargetPortion;
    uint256 public totalBorrowingTargetPortion;
    address[] public incentiveTokens;
    mapping(address => uint256) public tokenWeights;
    uint256 public totalTokenWeights;
    mapping(address => uint8) public tokenLendingTranches;
    mapping(address => uint8) public tokenBorrowingTranches;
    uint8 public nextTrancheIndex = 20;

    constructor(
        uint256 lendingTargetPortion,
        uint256 borrowingTargetPortion,
        address _roles
    ) RoleAware(_roles) Ownable() {
        totalLendingTargetPortion = lendingTargetPortion;
        totalBorrowingTargetPortion = borrowingTargetPortion;
    }

    function activateToken(
        address token,
        uint256 exposureCap,
        uint256 incentiveWeight
    ) external onlyOwner {
        Fund(fund()).activateToken(token);
        CrossMarginTrading(marginTrading()).setTokenCap(token, exposureCap);
        // TODO lending cap as well

        if (incentiveWeight > 0) {
            totalTokenWeights += incentiveWeight;
            tokenWeights[token] = incentiveWeight;
            IncentiveDistribution iD =
                IncentiveDistribution(incentiveDistributor());

            // init lending
            uint256 lendingShare =
                calcTrancheShare(incentiveWeight, totalLendingTargetPortion);
            iD.initTranche(nextTrancheIndex, lendingShare);
            tokenLendingTranches[token] = nextTrancheIndex;
            nextTrancheIndex++;
            // TODO tell lending the tranche id

            // init borrowing
            uint256 borrowingShare =
                calcTrancheShare(incentiveWeight, totalBorrowingTargetPortion);
            iD.initTranche(nextTrancheIndex, borrowingShare);
            tokenBorrowingTranches[token] = nextTrancheIndex;
            nextTrancheIndex++;
            // TODO tell borrowing the tranche (or router or something)

            for (uint8 i = 0; incentiveTokens.length > i; i++) {
                address incentiveToken = incentiveTokens[i];
                uint256 tokenWeight = tokenWeights[incentiveToken];
                lendingShare = calcTrancheShare(
                    tokenWeight,
                    totalLendingTargetPortion
                );
                iD.setTrancheShare(
                    tokenLendingTranches[incentiveToken],
                    lendingShare
                );

                borrowingShare = calcTrancheShare(
                    tokenWeight,
                    totalBorrowingTargetPortion
                );
                iD.setTrancheShare(
                    tokenBorrowingTranches[incentiveToken],
                    borrowingShare
                );
            }
            incentiveTokens.push(token);
        }
    }

    function calcTrancheShare(uint256 incentiveWeight, uint256 targetPortion)
        internal
        view
        returns (uint256)
    {
        return (incentiveWeight * targetPortion) / totalTokenWeights;
    }

    function setLendingTargetPortion(uint256 portion) external onlyOwner {
        totalLendingTargetPortion = portion;
    }

    function setBorrowingTargetPortion(uint256 portion) external onlyOwner {
        totalBorrowingTargetPortion = portion;
    }

    function relinquishOwnershipOfDistributor(address newOwner)
        external
        onlyOwner
    {
        IncentiveDistribution(incentiveDistributor()).transferOwnership(
            newOwner
        );
    }
}
