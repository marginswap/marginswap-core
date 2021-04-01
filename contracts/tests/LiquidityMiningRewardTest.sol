pragma solidity ^0.8.0;

import "../LiquidityMiningReward.sol";
import "@openzeppelin/contracts/token/ERC20/presets/ERC20PresetMinterPauser.sol";
import "../Roles.sol";
import "../Fund.sol";
import "../IncentiveDistribution.sol";

contract LiquidityMiningRewardTest {
    address constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    uint16 public constant WITHDRAWER = 1;
    uint16 public constant MARGIN_CALLER = 2;
    uint16 public constant BORROWER = 3;
    uint16 public constant MARGIN_TRADER = 4;
    uint16 public constant FEE_SOURCE = 5;
    uint16 public constant LIQUIDATOR = 6;
    uint16 public constant AUTHORIZED_FUND_TRADER = 7;
    uint16 public constant INCENTIVE_REPORTER = 8;
    uint16 public constant TOKEN_ACTIVATOR = 9;

    uint16 public constant FUND = 101;
    uint16 public constant LENDING = 102;
    uint16 public constant ROUTER = 103;
    uint16 public constant MARGIN_TRADING = 104;
    uint16 public constant FEE_CONTROLLER = 105;
    uint16 public constant PRICE_CONTROLLER = 106;

    ERC20PresetMinterPauser stakeToken;
    ERC20PresetMinterPauser rewardToken;
    LiquidityMiningReward liqui;
    IncentiveDistribution incentiveDistro;

    constructor() {
        // deploy roles
        Roles roles = new Roles();
        Fund fund = new Fund(WETH, address(roles));
        roles.setMainCharacter(FUND, address(fund));

        rewardToken = new ERC20PresetMinterPauser("Reward Token", "REW");
        rewardToken.mint(address(fund), 100_000 ether);
        // TODO activate in lending instead
        //fund.activateToken(address(rewardToken));

        incentiveDistro = new IncentiveDistribution(
            address(rewardToken),
            4_000,
            address(roles)
        );
        roles.giveRole(WITHDRAWER, address(incentiveDistro));
        incentiveDistro.initTranche(0, 200);

        stakeToken = new ERC20PresetMinterPauser("Stake Token", "STK");
        stakeToken.mint(address(this), 20_000 ether);

        liqui = new LiquidityMiningReward(
            address(incentiveDistro),
            address(stakeToken),
            block.timestamp - 1
        );

        roles.giveRole(INCENTIVE_REPORTER, address(liqui));
    }

    function stake(uint256 amount) public returns (uint256 stakeBalance) {
        stakeToken.approve(address(liqui), amount * (1 ether));
        liqui.depositStake(amount * (1 ether));
        stakeBalance = stakeToken.balanceOf(address(this));
        require(
            liqui.stakeAmounts(address(this)) == amount * (1 ether),
            "Incorrect stake amount"
        );
    }

    function withdrawStake(uint256 amount)
        public
        returns (uint256 stakeBalance, uint256 incentiveBalance)
    {
        liqui.withdrawStake(amount * (1 ether));
        stakeBalance = stakeToken.balanceOf(address(this));
        incentiveBalance = rewardToken.balanceOf(address(this));
    }

    function withdrawReward(uint256 expectedReward)
        public
        returns (uint256 stakeBalance, uint256 incentiveBalance)
    {
        uint256 initialIncentiveBalance = rewardToken.balanceOf(address(this));
        liqui.withdrawReward();
        stakeBalance = stakeToken.balanceOf(address(this));
        incentiveBalance = rewardToken.balanceOf(address(this));
        uint256 incentiveBalanceDiff =
            incentiveBalance - initialIncentiveBalance;
        require(
            incentiveBalanceDiff > expectedReward * 1 ether,
            "Reward did not grow enough"
        );
    }

    function stakeAmount() public view returns (uint256 amount) {
        amount = liqui.stakeAmounts(address(this));
    }

    function updateReward() public {
        incentiveDistro.forcePeriodTotalUpdate(0);
    }

    function rewardBalance() public view returns (uint24 balance) {
        balance = uint24(incentiveDistro.viewRewardAmount(0, 1) / (1 ether));
    }
}
// jump ahead 1 period,2 periods, 4 periods and then 2 days
