// SPDX-License-Identifier: GPL-2.0-only
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "./IncentiveDistribution.sol";
import "./RoleAware.sol";
import "./Fund.sol";
import "./CrossMarginTrading.sol";

contract Admin is RoleAware, Ownable {
    address MFI;
    mapping(address => uint256) public stakes;
    uint256 public totalStakes;
    mapping(address => uint256) public claimIds;

    uint256 feesPer10k;
    mapping(address => uint256) public collectedFees;

    uint256 public maintenanceStakePerBlock;
    mapping(address => address) public nextMaintenanceStaker;
    mapping(address => mapping(address => bool)) public maintenanceDelegateTo;
    address currentMaintenanceStaker;
    address prevMaintenanceStaker;
    uint256 currentMaintenanceStakerStartBlock;

    // TODO initialize the above

    constructor(
        uint256 _feesPer10k,
        address _MFI,
        address _roles
    ) RoleAware(_roles) Ownable() {
        MFI = _MFI;
        feesPer10k = _feesPer10k;
        maintenanceStakePerBlock = 1 ether;
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
            IncentiveDistribution(incentiveDistributor()).addToClaimAmount(
                0,
                claimIds[holder],
                amount
            );
        } else {
            uint256 claimId =
                IncentiveDistribution(incentiveDistributor()).startClaim(
                    0,
                    holder,
                    amount
                );
            claimIds[msg.sender] = claimId;
            require(claimId > 0, "Distribution is over or paused");
        }
    }

    function depositStake(uint256 amount) external {
        _stake(msg.sender, amount);
    }

    function _withdrawStake(
        address holder,
        uint256 amount,
        address recipient
    ) internal {
        uint256 stakeAmount = stakes[holder];
        // overflow failure desirable
        stakes[holder] = amount;
        totalStakes -= amount;
        require(
            Fund(fund()).withdraw(MFI, recipient, amount),
            "Insufficient funds -- something went really wrong."
        );
        if (stakeAmount == amount) {
            IncentiveDistribution(incentiveDistributor()).endClaim(
                0,
                claimIds[holder]
            );
            claimIds[holder] = 0;
        } else {
            IncentiveDistribution(incentiveDistributor())
                .subtractFromClaimAmount(0, claimIds[holder], amount);
        }
    }

    function withdrawStake(uint256 amount) external {
        require(
            !isAuthorizedStaker(msg.sender),
            "You can't withdraw while you're authorized staker"
        );
        _withdrawStake(msg.sender, amount, msg.sender);
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
            amount + stakes[msg.sender] >= maintenanceStakePerBlock,
            "Insufficient stake to call even one block"
        );
        _stake(msg.sender, amount);
        if (nextMaintenanceStaker[msg.sender] == address(0)) {
            nextMaintenanceStaker[msg.sender] = getUpdatedCurrentStaker();
            nextMaintenanceStaker[prevMaintenanceStaker] = msg.sender;
        }
    }

    function getUpdatedCurrentStaker() public returns (address) {
        while (
            (block.number - currentMaintenanceStakerStartBlock) *
                maintenanceStakePerBlock >=
            stakes[currentMaintenanceStaker]
        ) {
            if (maintenanceStakePerBlock > stakes[currentMaintenanceStaker]) {
                // delete current from daisy chain
                address nextOne =
                    nextMaintenanceStaker[currentMaintenanceStaker];
                nextMaintenanceStaker[prevMaintenanceStaker] = nextOne;
                nextMaintenanceStaker[currentMaintenanceStaker] = address(0);

                currentMaintenanceStaker = nextOne;
            } else {
                currentMaintenanceStakerStartBlock +=
                    stakes[currentMaintenanceStaker] /
                    maintenanceStakePerBlock;
                prevMaintenanceStaker = currentMaintenanceStaker;
                currentMaintenanceStaker = nextMaintenanceStaker[
                    currentMaintenanceStaker
                ];
            }
        }
        return currentMaintenanceStaker;
    }

    // TODO rethink authorization
    function addDelegate(address forStaker, address delegate) external {
        require(
            msg.sender == forStaker ||
                maintenanceDelegateTo[forStaker][msg.sender],
            "msg.sender not authorized to delegate for staker"
        );
        maintenanceDelegateTo[forStaker][delegate] = true;
    }

    function removeDelegate(address forStaker, address delegate) external {
        require(
            msg.sender == forStaker ||
                maintenanceDelegateTo[forStaker][msg.sender],
            "msg.sender not authorized to delegate for staker"
        );
        maintenanceDelegateTo[forStaker][delegate] = false;
    }

    function isAuthorizedStaker(address caller)
        public
        returns (bool isAuthorized)
    {
        address currentStaker = getUpdatedCurrentStaker();
        isAuthorized =
            currentStaker == caller ||
            maintenanceDelegateTo[currentStaker][caller];
    }

    function penalizeMaintenanceStake(
        address maintainer,
        uint256 penalty,
        address recipient
    ) external returns (uint256 stakeTaken) {
        require(
            isStakePenalizer(msg.sender),
            "msg.sender not authorized to penalize stakers"
        );
        if (penalty > stakes[maintainer]) {
            stakeTaken = stakes[maintainer];
        } else {
            stakeTaken = penalty;
        }
        _withdrawStake(maintainer, stakeTaken, recipient);
    }
}
