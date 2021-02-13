import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/math/SafeMath.sol';

import './RoleAware.sol';
import './Fund.sol';

struct MarginCallingStake {
    uint stake;
    address nextStaker;
}

contract Admin is RoleAware, Ownable {
    using SafeMath for uint;
    address MFI;
    mapping(address => uint) public stakes;
    uint public totalStakes;

    uint feesPer10k;
    mapping(address => uint) public collectedFees;

    uint mcStakePerBlock;
    mapping(address => MarginCallingStake) public mcStakes;
    address currentMCStaker;
    address prevMCStaker;
    uint currentStakerStartBlock;
    // TODO initialize the above

    constructor(uint _feesPer10k, address _MFI, address _roles) RoleAware(_roles) Ownable() {
        MFI = _MFI;
        feesPer10k = _feesPer10k;
        mcStakePerBlock = 1 ether;
    }

    function _stake(address holder, uint amount) internal {
        require(Fund(fund()).depositFor(holder, MFI, amount),
                "Could not deposit stake funds (perhaps make allowance to fund contract?");
        stakes[msg.sender] += amount;
        totalStakes += amount;
    }

    function stake(uint amount) external {
        _stake(msg.sender, amount);
    }

    function unstake(uint amount, address recipient) external {
        // overflow failure desirable
        stakes[msg.sender] -= amount;
        totalStakes -= amount;
        require(Fund(fund()).withdraw(MFI, recipient, amount),
                "Insufficient funds -- something went really wrong.");
    }

    function addTradingFees(address token, uint amount) external returns (uint fees) {
        require(isFeeSource(msg.sender), "Not authorized to source fees");
        fees = feesPer10k * amount / 10_000;
        collectedFees[token] += fees;
    }

    function subtractTradingFees(address token, uint amount) external returns (uint fees) {
        require(isFeeSource(msg.sender), "Not authorized to source fees");
        fees = feesPer10k * amount / (10_000 + feesPer10k);
        collectedFees[token] += fees;
    }

    function marginCallerStake(uint amount) external {
        require(amount + mcStakes[msg.sender].stake >= mcStakePerBlock, "Insufficient stake to call even one block");
        _stake(msg.sender, amount);
        if (mcStakes[msg.sender].stake == 0) {
            // TODO make sure we delete from list when all is withdrawl again
            mcStakes[msg.sender].stake = amount;
            mcStakes[msg.sender].nextStaker = getUpdatedCurrentStaker();
            mcStakes[prevMCStaker].nextStaker = msg.sender;
        }
    }

    function getUpdatedCurrentStaker() internal returns (address) {
        while((block.number - currentStakerStartBlock) * mcStakePerBlock >= mcStakes[currentMCStaker].stake) {
            currentStakerStartBlock += mcStakes[currentMCStaker].stake / mcStakePerBlock;
            prevMCStaker = currentMCStaker;
            currentMCStaker = mcStakes[currentMCStaker].nextStaker;
        }
        return currentMCStaker;
    }
}
