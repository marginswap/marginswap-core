// SPDX-License-Identifier: GPL-2.0-only
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./IncentiveDistribution.sol";

contract LiquidityMiningReward {
    using SafeERC20 for IERC20;

    IERC20 public stakeToken;
    mapping(address => uint256) public claimIds;
    mapping(address => uint256) public stakeAmounts;
    IncentiveDistribution incentiveDistributor;
    uint256 public incentiveStart;

    constructor(
        address _incentiveDistributor,
        address _stakeToken,
        uint256 startTimestamp
    ) {
        incentiveDistributor = IncentiveDistribution(_incentiveDistributor);
        stakeToken = IERC20(_stakeToken);
        incentiveStart = startTimestamp;
    }

    function depositStake(uint256 amount) external {
        require(
            block.timestamp > incentiveStart,
            "Incentive hasn't started yet"
        );
        stakeToken.safeTransferFrom(msg.sender, address(this), amount);
        if (claimIds[msg.sender] > 0) {
            incentiveDistributor.addToClaimAmount(
                0,
                claimIds[msg.sender],
                amount
            );
        } else {
            uint256 claimId =
                incentiveDistributor.startClaim(0, msg.sender, amount);
            claimIds[msg.sender] = claimId;
        }
        stakeAmounts[msg.sender] += amount;
    }

    function withdrawStake() external {
        if (stakeAmounts[msg.sender] > 0) {
            stakeToken.safeTransfer(msg.sender, stakeAmounts[msg.sender]);
            stakeAmounts[msg.sender] = 0;
            incentiveDistributor.endClaim(0, claimIds[msg.sender]);
            claimIds[msg.sender] = 0;
        }
    }
}

// USDC - MFI pair token
// 0x9d640080af7c81911d87632a7d09cc4ab6b133ac
