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
  const { deployer, baseCurrency, amm1Factory, amm2Factory, amm3Factory } = await getNamedAccounts();
  const Roles = await deployments.get('Roles');

  const amm1InitHash = amm1InitHashes[await getChainId()];
  const amm2InitHash = amm2InitHashes[await getChainId()];
  const amm3InitHash = amm3InitHashes[await getChainId()];

  await deploy('MarginRouter', {
    from: deployer,
    args: [baseCurrency, amm1Factory, amm2Factory, amm3Factory, amm1InitHash, amm2InitHash, amm3InitHash, Roles.address],
    log: true,
    skipIfAlreadyDeployed: true
  });
};
deploy.tags = ['MarginRouter', 'local'];
deploy.dependencies = ['Roles'];
export default deploy;
