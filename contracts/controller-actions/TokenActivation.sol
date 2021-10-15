// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "../Executor.sol";

import "../CrossMarginTrading.sol";
import "../MarginRouter.sol";
import "../PriceAware.sol";

contract TokenActivation is Executor {
    address[] public tokens;
    uint256[] public exposureCaps;
    address[] public oracleContracts;

    uint256 constant initHourlyYieldAPRPercent = 0;

    bytes32[] public amms;
    address[][] public liquidationTokens;

    constructor(
        address _roles,
        address[] memory tokens2activate,
        uint256[] memory _exposureCaps,
        bytes32[] memory _amms,
        address[][] memory _liquidationTokens,
        address[] memory _oracleContracts
    ) RoleAware(_roles) {
        tokens = tokens2activate;
        exposureCaps = _exposureCaps;

        amms = _amms;
        liquidationTokens = _liquidationTokens;
        oracleContracts = _oracleContracts;
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
            Lending(lending()).setHourlyYieldAPR(
                token,
                initHourlyYieldAPRPercent
            );
            Lending(lending()).initBorrowYieldAccumulator(token);

            require(
                liquidationTokenPath.length == 0 ||
                    (liquidationTokenPath[0] == token &&
                        liquidationTokenPath[liquidationTokenPath.length - 1] ==
                        CrossMarginTrading(crossMarginTrading()).peg()),
                "Invalid liquidationTokens -- should go from token to peg"
            );

            if (oracleContracts[i] != address(0)) {
                if (liquidationTokenPath.length > 0) {
                    PriceAware(oracleContracts[i]).setLiquidationPath(
                        ammPath,
                        liquidationTokenPath
                    );
                }
                CrossMarginTrading(crossMarginTrading()).setPriceOracle(
                    token,
                    oracleContracts[i]
                );
            } else {
                CrossMarginTrading(crossMarginTrading()).setLiquidationPath(
                    ammPath,
                    liquidationTokenPath
                );
            }
        }

        delete tokens;
        delete exposureCaps;
        delete amms;
        delete liquidationTokens;
        selfdestruct(payable(tx.origin));
    }
}
