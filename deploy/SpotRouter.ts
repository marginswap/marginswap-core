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
  const { deployer, weth } = await getNamedAccounts();

  await deploy('SpotRouter', {
    from: deployer,
    args: [weth],
    log: true,
    skipIfAlreadyDeployed: true,
    deterministicDeployment: true
  });
};
deploy.tags = ['SpotRouter', 'local'];
deploy.dependencies = [];
export default deploy;
