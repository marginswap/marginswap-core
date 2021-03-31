// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "./SelfDestructReturningExec.sol";
import "../TokenAdmin.sol";

contract TokenActivation is SelfDestructReturningExec {
    uint256 public constant TOKEN_ADMIN = 109;
    address[] public tokens;
    uint256[] public exposureCaps;
    uint256[] public lendingBuffers;
    uint256[] public incentiveWeights;
    address[][] public liquidationPairs;
    address[][] public liquidationTokens;

    constructor(address controller,
                address[] memory tokens2activate,
                uint256[] memory _exposureCaps,
                uint256[] memory _lendingBuffers,
                uint256[] memory _incentiveWeights,
                address[][] memory _liquidationPairs,
                address[][] memory _liquidationTokens
                )
        SelfDestructReturningExec(controller)
    {
        tokens = tokens2activate;
        exposureCaps = _exposureCaps;
        lendingBuffers = _lendingBuffers;
        incentiveWeights = _incentiveWeights;
        liquidationPairs = _liquidationPairs;
        liquidationTokens = _liquidationTokens;
        
        propertyCharacters.push(TOKEN_ADMIN);
        
    }

    function _execute() internal override {
        for (uint24 i = 0; tokens.length > i; i++) {
            address token = tokens[i];
            uint256 exposureCap = exposureCaps[i];
            uint256 lendingBuffer = lendingBuffers[i];
            uint256 incentiveWeight = incentiveWeights[i];
            address[] memory liquidationPairPath = liquidationPairs[i];
            address[] memory liquidationTokenPath = liquidationTokens[i];

            TokenAdmin(roles().mainCharacters(TOKEN_ADMIN))
                .activateToken(token,
                               exposureCap,
                               lendingBuffer,
                               incentiveWeight,
                               liquidationPairPath,
                               liquidationTokenPath);
        }
    }
}
