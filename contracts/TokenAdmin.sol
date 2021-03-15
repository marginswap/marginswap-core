// SPDX-License-Identifier: GPL-2.0-only
pragma solidity ^0.8.0;

import "./RoleAware.sol";
import "./IncentiveDistribution.sol";
import "./Fund.sol";
import "./CrossMarginTrading.sol";
import "./MarginRouter.sol";
import "../interfaces/IDelegateOwner.sol";

contract TokenAdmin is RoleAware, Ownable, IDelegateOwner {
    uint256 public totalLendingTargetPortion;
    uint256 public totalBorrowingTargetPortion;
    address[] public incentiveTokens;
    mapping(address => uint256) public tokenWeights;
    uint256 public totalTokenWeights;
    mapping(address => uint8) public tokenLendingTranches;
    mapping(address => uint8) public tokenBorrowingTranches;
    uint8 public nextTrancheIndex = 20;

    uint256 public initHourlyYieldAPRPercent = 10;

    // TODO give this contract ownership of incentive distribution
    // after everything else is incentivized
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
        uint256 lendingBuffer,
        uint256 incentiveWeight,
        address[] memory liquidationPath
    ) external onlyOwner {
        require(!Fund(fund()).activeTokens(token), "Token already is active");

        Fund(fund()).activateToken(token);
        CrossMarginTrading(marginTrading()).setTokenCap(token, exposureCap);
        Lending(lending()).setLendingCap(token, exposureCap);
        Lending(lending()).setLendingBuffer(token, lendingBuffer);
        Lending(lending()).setHourlyYieldAPR(token, initHourlyYieldAPRPercent);
        Lending(lending()).initBorrowYieldAccumulator(token);

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
            Lending(lending()).setIncentiveTranche(token, nextTrancheIndex);
            nextTrancheIndex++;

            // init borrowing
            uint256 borrowingShare =
                calcTrancheShare(incentiveWeight, totalBorrowingTargetPortion);
            iD.initTranche(nextTrancheIndex, borrowingShare);
            tokenBorrowingTranches[token] = nextTrancheIndex;
            MarginRouter(router()).setIncentiveTranche(token, nextTrancheIndex);
            nextTrancheIndex++;

            updateIncentiveShares(iD);
            incentiveTokens.push(token);

            require(
                liquidationPath[0] == token &&
                    liquidationPath[liquidationPath.length - 1] ==
                    CrossMarginTrading(marginTrading()).peg(),
                "Invalid liquidationPath -- should go from token to peg"
            );
            CrossMarginTrading(marginTrading()).setLiquidationPath(
                liquidationPath
            );
        }
    }

    function changeTokenCap(address token, uint256 exposureCap)
        external
        onlyOwner
    {
        Lending(lending()).setLendingCap(token, exposureCap);
        CrossMarginTrading(marginTrading()).setTokenCap(token, exposureCap);
    }

    function changeTokenIncentiveWeight(address token, uint256 tokenWeight)
        external
        onlyOwner
    {
        totalTokenWeights =
            totalTokenWeights +
            tokenWeight -
            tokenWeights[token];
        tokenWeights[token] = tokenWeight;

        updateIncentiveShares(IncentiveDistribution(incentiveDistributor()));
    }

    function changeLendingBuffer(address token, uint256 lendingBuffer)
        external
        onlyOwner
    {
        Lending(lending()).setLendingBuffer(token, lendingBuffer);
    }

    //function changeBondLendingWeights(address token, uint256[] memory weights) external onlyOwner {
    //    Lending(lending()).setRuntimeWeights(token, weights);
    //}

    function updateIncentiveShares(IncentiveDistribution iD) internal {
        for (uint8 i = 0; incentiveTokens.length > i; i++) {
            address incentiveToken = incentiveTokens[i];
            uint256 tokenWeight = tokenWeights[incentiveToken];
            uint256 lendingShare =
                calcTrancheShare(tokenWeight, totalLendingTargetPortion);
            iD.setTrancheShare(
                tokenLendingTranches[incentiveToken],
                lendingShare
            );

            uint256 borrowingShare =
                calcTrancheShare(tokenWeight, totalBorrowingTargetPortion);
            iD.setTrancheShare(
                tokenBorrowingTranches[incentiveToken],
                borrowingShare
            );
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

    function changeHourlyYieldAPR(address token, uint256 aprPercent)
        external
        onlyOwner
    {
        Lending(lending()).setHourlyYieldAPR(token, aprPercent);
    }

    function setInitHourlyYieldAPR(uint256 value) external onlyOwner {
        initHourlyYieldAPRPercent = value;
    }

    function relinquishOwnership(address property, address newOwner)
        external
        override
        onlyOwner
    {
        Ownable(property).transferOwnership(newOwner);
    }
}
