import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";

import "./RoleAware.sol";
import "./Fund.sol";
import "./MarginTrading.sol";

struct MarginCallingStake {
    uint256 stake;
    address nextStaker;
}

contract Admin is RoleAware, Ownable {
    using SafeMath for uint256;
    address MFI;
    mapping(address => uint256) public stakes;
    uint256 public totalStakes;

    uint256 feesPer10k;
    mapping(address => uint256) public collectedFees;

    uint256 mcStakePerBlock;
    mapping(address => MarginCallingStake) public mcStakes;
    mapping(address => mapping(address => bool)) public mcDelegatedTo;
    address currentMCStaker;
    address prevMCStaker;
    uint256 currentStakerStartBlock;

    // TODO initialize the above

    constructor(
        uint256 _feesPer10k,
        address _MFI,
        address _roles
    ) RoleAware(_roles) Ownable() {
        MFI = _MFI;
        feesPer10k = _feesPer10k;
        mcStakePerBlock = 1 ether;
    }

    function _stake(address holder, uint256 amount) internal {
        require(
            Fund(fund()).depositFor(holder, MFI, amount),
            "Could not deposit stake funds (perhaps make allowance to fund contract?"
        );
        stakes[msg.sender] += amount;
        totalStakes += amount;
    }

    function stake(uint256 amount) external {
        _stake(msg.sender, amount);
    }

    function unstake(uint256 amount, address recipient) external {
        // overflow failure desirable
        stakes[msg.sender] -= amount;
        totalStakes -= amount;
        require(
            Fund(fund()).withdraw(MFI, recipient, amount),
            "Insufficient funds -- something went really wrong."
        );
    }

    function addTradingFees(address token, uint256 amount)
        external
        returns (uint256 fees)
    {
        require(isFeeSource(msg.sender), "Not authorized to source fees");
        fees = (feesPer10k * amount) / 10_000;
        collectedFees[token] += fees;
    }

    function subtractTradingFees(address token, uint256 amount)
        external
        returns (uint256 fees)
    {
        require(isFeeSource(msg.sender), "Not authorized to source fees");
        fees = (feesPer10k * amount) / (10_000 + feesPer10k);
        collectedFees[token] += fees;
    }

    function marginCallerStake(uint256 amount) external {
        require(
            amount + mcStakes[msg.sender].stake >= mcStakePerBlock,
            "Insufficient stake to call even one block"
        );
        _stake(msg.sender, amount);
        if (mcStakes[msg.sender].stake == 0) {
            // TODO make sure we delete from list when all is withdrawl again
            mcStakes[msg.sender].stake = amount;
            mcStakes[msg.sender].nextStaker = getUpdatedCurrentStaker();
            mcStakes[prevMCStaker].nextStaker = msg.sender;
        }
    }

    function getUpdatedCurrentStaker() internal returns (address) {
        while (
            (block.number - currentStakerStartBlock) * mcStakePerBlock >=
            mcStakes[currentMCStaker].stake
        ) {
            currentStakerStartBlock +=
                mcStakes[currentMCStaker].stake /
                mcStakePerBlock;
            prevMCStaker = currentMCStaker;
            currentMCStaker = mcStakes[currentMCStaker].nextStaker;
        }
        return currentMCStaker;
    }

    function addDelegate(address forStaker, address delegate) external {
        require(
            msg.sender == forStaker || mcDelegatedTo[forStaker][msg.sender],
            "msg.sender not authorized to delegate for staker"
        );
        mcDelegatedTo[forStaker][delegate] = true;
    }

    function removeDelegate(address forStaker, address delegate) external {
        require(
            msg.sender == forStaker || mcDelegatedTo[forStaker][msg.sender],
            "msg.sender not authorized to delegate for staker"
        );
        mcDelegatedTo[forStaker][delegate] = false;
    }

    function callMargin(address[] memory traders) external noIntermediary {
        address currentStaker = getUpdatedCurrentStaker();
        bool isAuthorized =
            currentStaker == msg.sender ||
                mcDelegatedTo[currentStaker][msg.sender];

        uint256 mcFees =
            MarginTrading(marginTrading()).callMargin(
                traders,
                getUpdatedCurrentStaker(),
                msg.sender,
                isAuthorized
            );
        // attacker mode
        // store both the returns and who was originally responsible
        // if the responsible address doesn't update within a certain time window, they lose their staked token
        // and they lose a portion of their earnings with every step..
        // if the current caller isn't the responsible party they may still be reclaiming what was called before
        // probably 5 seconds is the window? I.e. 50 blocks?

        // store first past the post attacker
        //
    }
}

// what if it keeps climbing beyond insurance? do we close position? -- I think we have to.
// we just shouldn't make new loans to that
