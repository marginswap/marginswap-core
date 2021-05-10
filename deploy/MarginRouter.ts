import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { DeployFunction } from 'hardhat-deploy/types';
import { amm1InitHashes, amm2InitHashes } from './SpotRouter';

const deploy: DeployFunction = async function ({
  getNamedAccounts,
  deployments,
  getChainId,
  getUnnamedAccounts,
  network
}: HardhatRuntimeEnvironment) {
  const { deploy } = deployments;
  const { deployer, weth, amm1Factory, amm2Factory } = await getNamedAccounts();
  const Roles = await deployments.get('Roles');

  const amm1InitHash = amm1InitHashes[await getChainId()];
  const amm2InitHash = amm2InitHashes[await getChainId()];
  await deploy('MarginRouter', {
    from: deployer,
    args: [weth, amm1Factory, amm2Factory, amm1InitHash, amm2InitHash, Roles.address],
    log: true,
    skipIfAlreadyDeployed: true
  });
};
deploy.tags = ['MarginRouter', 'local'];
deploy.dependencies = ['Roles'];
export default deploy;
