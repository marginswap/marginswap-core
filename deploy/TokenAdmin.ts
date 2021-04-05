import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { DeployFunction } from 'hardhat-deploy/types';

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
  const lendingTargetPortion = 400;
  const borrowingTargetPortion = 300;

  await deploy('TokenAdmin', {
    from: deployer,
    args: [lendingTargetPortion, borrowingTargetPortion, Roles.address],
    log: true,
    skipIfAlreadyDeployed: true
  });
};
deploy.tags = ['TokenAdmin', 'local'];
deploy.dependencies = ['Roles'];
export default deploy;
