// SPDX-License-Identifier: GPL-2.0-only
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "./IncentiveDistribution.sol";
import "./RoleAware.sol";
import "./Fund.sol";
import "./CrossMarginTrading.sol";

struct MarginCallingStake {
    uint256 stake;
    address nextStaker;
}

contract Admin is RoleAware, Ownable {
    address MFI;
    mapping(address => uint256) public stakes;
    uint256 public totalStakes;
    mapping(address => uint256) public claimIds;
    IncentiveDistribution incentiveDistributor;

    uint256 feesPer10k;
    mapping(address => uint256) public collectedFees;

    uint256 public maintenanceStakePerBlock;
    mapping(address => MarginCallingStake) public maintenanceStakes;
    mapping(address => mapping(address => bool)) public maintenanceDelegateTo;
    address currentMaintenanceStaker;
    address prevMaintenanceStaker;
    uint256 currentMaintenanceStakerStartBlock;

    // TODO initialize the above

    constructor(
        uint256 _feesPer10k,
        address _MFI,
        address _incentiveDistributor,
        address _roles
    ) RoleAware(_roles) Ownable() {
        MFI = _MFI;
        feesPer10k = _feesPer10k;
        maintenanceStakePerBlock = 1 ether;
        incentiveDistributor = IncentiveDistribution(_incentiveDistributor);
    }

    function setMaintenanceStakePerBlock(uint256 amount) external onlyOwner {
        maintenanceStakePerBlock = amount;
    }

    function _stake(address holder, uint256 amount) internal {
        require(
            Fund(fund()).depositFor(holder, MFI, amount),
            "Could not deposit stake funds (perhaps make allowance to fund contract?"
        );
        stakes[msg.sender] += amount;
        totalStakes += amount;


        if (claimIds[holder] > 0) {
            incentiveDistributor.addToClaimAmount(
                0,
                claimIds[holder],
                amount
            );
        } else {
            uint256 claimId =
                incentiveDistributor.startClaim(0, holder, amount);
            claimIds[msg.sender] = claimId;
            require(claimId > 0, "Distribution is over or paused");
        }
    }

    function depositStake(uint256 amount) external {
        _stake(msg.sender, amount);
    }

    function _withdrawStake(address holder, uint256 amount) internal {
        uint256 stakeAmount = stakes[holder];
        // overflow failure desirable
        stakes[holder] = amount;
        totalStakes -= amount;
        require(
            Fund(fund()).withdraw(MFI, holder, amount),
            "Insufficient funds -- something went really wrong."
        );
        if (stakeAmount == amount) {
            incentiveDistributor.endClaim(0, claimIds[holder]);
            claimIds[holder] = 0;
        } else {
            incentiveDistributor.subtractFromClaimAmount(
                0,
                claimIds[holder],
                amount
            );
        }
    }

    function withdrawStake(uint256 amount) external {
        _withdrawStake(msg.sender, amount);
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

    function depositMaintenanceStake(uint256 amount) external {
        require(
            amount + maintenanceStakes[msg.sender].stake >= maintenanceStakePerBlock,
            "Insufficient stake to call even one block"
        );
        _stake(msg.sender, amount);
        if (maintenanceStakes[msg.sender].stake == 0) {
            // TODO make sure we delete from list when all is withdrawl again
            maintenanceStakes[msg.sender].stake = amount;
            maintenanceStakes[msg.sender].nextStaker = getUpdatedCurrentStaker();
            maintenanceStakes[prevMaintenanceStaker].nextStaker = msg.sender;
        }
    }

    function getUpdatedCurrentStaker() internal returns (address) {
        while (
            (block.number - currentMaintenanceStakerStartBlock) * maintenanceStakePerBlock >=
            maintenanceStakes[currentMaintenanceStaker].stake
        ) {
            currentMaintenanceStakerStartBlock +=
                maintenanceStakes[currentMaintenanceStaker].stake /
                maintenanceStakePerBlock;
            prevMaintenanceStaker = currentMaintenanceStaker;
            currentMaintenanceStaker = maintenanceStakes[currentMaintenanceStaker].nextStaker;
        }
        return currentMaintenanceStaker;
    }

    function addDelegate(address forStaker, address delegate) external {
        require(
            msg.sender == forStaker || maintenanceDelegateTo[forStaker][msg.sender],
            "msg.sender not authorized to delegate for staker"
        );
        maintenanceDelegateTo[forStaker][delegate] = true;
    }

    function removeDelegate(address forStaker, address delegate) external {
        require(
            msg.sender == forStaker || maintenanceDelegateTo[forStaker][msg.sender],
            "msg.sender not authorized to delegate for staker"
        );
        maintenanceDelegateTo[forStaker][delegate] = false;
    }

    function isAuthorizedStaker(address caller) external returns (bool isAuthorized) {
        address currentStaker = getUpdatedCurrentStaker();
        isAuthorized =
            currentStaker == caller ||
                maintenanceDelegateTo[currentStaker][caller];
    }
}
