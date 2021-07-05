import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { DeployFunction } from 'hardhat-deploy/types';
import { ethers } from 'hardhat';

const deploy: DeployFunction = async function ({
  getNamedAccounts,
  deployments,
  getChainId,
  getUnnamedAccounts,
  network
}: HardhatRuntimeEnvironment) {
  const { deploy } = deployments;
  const { deployer, mfiAddress } = await getNamedAccounts();

  const Staking = await deploy('Staking', {
    from: deployer,
    args: [mfiAddress, mfiAddress, (await deployments.get('MFIStaking')).address],
    log: true,
    skipIfAlreadyDeployed: true
  });
};

deploy.tags = ['Staking', 'local'];
deploy.dependencies = ['Roles'];
export default deploy;