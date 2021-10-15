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
  const { deployer, mfiAddress } = await getNamedAccounts();

  const roles = await deployments.get('Roles').then(Roles => ethers.getContractAt('Roles', Roles.address));

  // 15k per month
  const initialRewardPerBlock = ethers.utils.parseEther('15000').div(30 * 24 * 60 * 4);
  // const Staking = await deploy('MFIStaking', {
  //   from: deployer,
  //   args: [mfiAddress, initialRewardPerBlock, roles.address],
  //   log: true,
  //   skipIfAlreadyDeployed: true
  // });
};

deploy.tags = ['MFIStaking', 'local'];
deploy.dependencies = ['Roles'];
export default deploy;
