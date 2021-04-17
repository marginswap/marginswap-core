// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "../Executor.sol";

import "../CrossMarginTrading.sol";
import "../MarginRouter.sol";
import "../IncentiveDistribution.sol";

contract TokenActivation is Executor {
    address[] public tokens;
    uint256[] public exposureCaps;
    uint256[] public lendingBuffers;

    uint256 constant initHourlyYieldAPRPercent = 0;

    bytes32[] public amms;
    address[][] public liquidationTokens;

    constructor(
        address _roles,
        address[] memory tokens2activate,
        uint256[] memory _exposureCaps,
        uint256[] memory _lendingBuffers,
        bytes32[] memory _amms,
        address[][] memory _liquidationTokens
    ) RoleAware(_roles) {
        tokens = tokens2activate;
        exposureCaps = _exposureCaps;
        lendingBuffers = _lendingBuffers;

        amms = _amms;
        liquidationTokens = _liquidationTokens;
    }

    function requiredRoles()
        external
        override
        returns (uint256[] memory required)
    {}

    function execute() external override {
        for (uint24 i = 0; tokens.length > i; i++) {
            address token = tokens[i];
            uint256 exposureCap = exposureCaps[i];
            uint256 lendingBuffer = lendingBuffers[i];

            bytes32 ammPath = amms[i];
            address[] memory liquidationTokenPath = liquidationTokens[i];

            require(
                !Lending(lending()).activeIssuers(token),
                "Token already is active"
            );

            Lending(lending()).activateIssuer(token);
            CrossMarginTrading(crossMarginTrading()).setTokenCap(
                token,
                exposureCap
            );
            Lending(lending()).setLendingCap(token, exposureCap);
            Lending(lending()).setLendingBuffer(token, lendingBuffer);
            Lending(lending()).setHourlyYieldAPR(
                token,
                initHourlyYieldAPRPercent
            );
            Lending(lending()).initBorrowYieldAccumulator(token);

            require(
                liquidationTokenPath[0] == token &&
                    liquidationTokenPath[liquidationTokenPath.length - 1] ==
                    CrossMarginTrading(crossMarginTrading()).peg(),
                "Invalid liquidationTokens -- should go from token to peg"
            );
            CrossMarginTrading(crossMarginTrading()).setLiquidationPath(
                ammPath,
                liquidationTokenPath
            );
        }

        delete tokens;
        delete exposureCaps;
        delete lendingBuffers;
        delete amms;
        delete liquidationTokens;
        selfdestruct(payable(tx.origin));
    }
}

// TODO SET TRANCHES
//             Lending(lending()).setIncentiveTranche(token, nextTrancheIndex);
//
//            MarginRouter(marginRouter()).setIncentiveTranche(
//              token,
//              nextTrancheIndex
//          );
