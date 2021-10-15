import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { DeployFunction } from 'hardhat-deploy/types';
import { ethers } from 'hardhat';

const INCENTIVE_REPORTER = 8;

const deploy: DeployFunction = async function ({
  getNamedAccounts,
  deployments,
  getChainId,
  getUnnamedAccounts,
  network
}: HardhatRuntimeEnvironment) {
  const { deploy } = deployments;
  const { deployer, liquidityToken, mfiAddress } = await getNamedAccounts();

  const roles = await deployments.get('Roles').then(Roles => ethers.getContractAt('Roles', Roles.address));

  // 5k per month
  //   const initialRewardPerBlock = ethers.utils.parseEther('5000').div(30 * 24 * 60 * 4);
  //   const Staking = await deploy('LiquidityMiningReward', {
  //     from: deployer,
  //     args: [mfiAddress, liquidityToken, initialRewardPerBlock, roles.address],
  //     log: true,
  //     skipIfAlreadyDeployed: true
  //   });
};

deploy.tags = ['LiquidityMiningReward', 'local'];
deploy.dependencies = ['Roles'];
export default deploy;
