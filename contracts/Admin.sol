import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/math/SafeMath.sol';

import './RoleAware.sol';
import './Fund.sol';


contract Admin is RoleAware, Ownable {
    using SafeMath for uint;
    address MFI;
    mapping(address => uint) public stakes;
    uint public totalStakes;

    uint feesPer10k;
    mapping(address => uint) public collectedFees;
    
    
    constructor(uint _feesPer10k, address _MFI, address _roles) RoleAware(_roles) Ownable() {
        MFI = _MFI;
        feesPer10k = _feesPer10k;
    }

    function stake(uint amount) external {
        require(Fund(fund()).depositFor(msg.sender, MFI, amount),
                "Could not deposit stake funds (perhaps make allowance to fund contract?");
        stakes[msg.sender] += amount;
        totalStakes += amount;
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
}
