import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./IncentiveDistribution.sol";

contract LiquidityMiningReward {
    using SafeERC20 for IERC20;

    IERC20 public stakeToken;
    mapping(address => uint256) public claimIds;
    mapping(address => uint256) public stakeAmounts;
    IncentiveDistribution incentiveDistributor;
    uint256 public incentiveStart;
    uint256 public lockEnd;
    constructor(address _incentiveDistributor,
                address _stakeToken,
                uint256 startTimestamp,
                uint256 lockEndTimestamp) {
        incentiveDistributor = IncentiveDistribution(_incentiveDistributor);
        stakeToken = IERC20(_stakeToken);
        incentiveStart = startTimestamp;
        lockEnd = lockEndTimestamp;
    }

    function depositStake(uint256 amount) external
    {
        require(block.timestamp > incentiveStart, "Incentive hasn't started yet");
        stakeToken.safeTransferFrom(msg.sender, address(this), amount);
        if (claimIds[msg.sender] > 0) {
            incentiveDistributor.addToClaimAmount(0, claimIds[msg.sender], amount);
        } else {
            uint256 claimId = incentiveDistributor.startClaim(0, msg.sender, amount);
            claimIds[msg.sender] = claimId;
        }
        stakeAmounts[msg.sender] += amount;
    }

    function withdrawStake() external {
        require(block.timestamp > lockEnd, "Stake rewards are currently still locked");
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
