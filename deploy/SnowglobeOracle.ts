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
  const { deployer } = await getNamedAccounts();
  const Roles = await deployments.get('Roles');
  const roles = await ethers.getContractAt('Roles', Roles.address);

  const Oracle = await deploy('SnowglobeOracle', {
    from: deployer,
    args: [6, roles.address],
    log: true,
    skipIfAlreadyDeployed: true
  });
};
deploy.tags = ['SnowglobeOracle'];
deploy.dependencies = ['Roles', 'RoleAware'];
export default deploy;
