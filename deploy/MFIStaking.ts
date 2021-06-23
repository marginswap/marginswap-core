import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { DeployFunction } from 'hardhat-deploy/types';
import { Contract } from 'ethers';
const { ethers } = require('hardhat');

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

  const Staking = await deploy('MFIStaking', {
    from: deployer,
    args: [mfiAddress, roles.address],
    log: true,
    skipIfAlreadyDeployed: true
  });
};

deploy.tags = ['MFIStaking', 'local'];
deploy.dependencies = ['Roles'];
export default deploy;