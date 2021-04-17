import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { DeployFunction } from 'hardhat-deploy/types';
const { ethers } = require('hardhat');

const deploy: DeployFunction = async function ({
  getNamedAccounts,
  deployments,
  getChainId,
  getUnnamedAccounts,
  network
}: HardhatRuntimeEnvironment) {
  const { deploy } = deployments;
  const { deployer, mfiAddress, lockedMfi, lockedMfiDelegate } = await getNamedAccounts();
  const Roles = await deployments.get('Roles');

  const Admin = await deploy('Admin', {
    from: deployer,
    args: [mfiAddress, lockedMfi, lockedMfiDelegate, Roles.address],
    log: true,
    skipIfAlreadyDeployed: true
  });
};
deploy.tags = ['Admin', 'local'];
deploy.dependencies = ['Roles', 'IncentiveDistribution'];
export default deploy;
