// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "../Executor.sol";
import "../TokenAdmin.sol";

contract TokenActivation is Executor {
    address[] public tokens;
    uint256[] public exposureCaps;
    uint256[] public lendingBuffers;
    uint256[] public incentiveWeights;
    address[][] public liquidationPairs;
    address[][] public liquidationTokens;

    constructor(address _roles,
                address[] memory tokens2activate,
                uint256[] memory _exposureCaps,
                uint256[] memory _lendingBuffers,
                uint256[] memory _incentiveWeights,
                address[][] memory _liquidationPairs,
                address[][] memory _liquidationTokens
                ) RoleAware(_roles)
    {
        tokens = tokens2activate;
        exposureCaps = _exposureCaps;
        lendingBuffers = _lendingBuffers;
        incentiveWeights = _incentiveWeights;
        liquidationPairs = _liquidationPairs;
        liquidationTokens = _liquidationTokens;
    }

    function requiredRoles() external override returns (uint256[] memory required) {
    }

    function execute() external override {
        for (uint24 i = 0; tokens.length > i; i++) {
            address token = tokens[i];
            uint256 exposureCap = exposureCaps[i];
            uint256 lendingBuffer = lendingBuffers[i];
            uint256 incentiveWeight = incentiveWeights[i];
            address[] memory liquidationPairPath = liquidationPairs[i];
            address[] memory liquidationTokenPath = liquidationTokens[i];

            TokenAdmin(tokenAdmin())
                .activateToken(token,
                               exposureCap,
                               lendingBuffer,
                               incentiveWeight,
                               liquidationPairPath,
                               liquidationTokenPath);
        }

        selfdestruct(payable(tx.origin));
    }
}
