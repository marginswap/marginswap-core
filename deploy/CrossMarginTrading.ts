import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { DeployFunction } from 'hardhat-deploy/types';
import { deployments } from 'hardhat';
import { amm1InitHashes, amm2InitHashes } from './SpotRouter';

const deploy: DeployFunction = async function ({
  getNamedAccounts,
  deployments,
  getChainId,
  getUnnamedAccounts,
  network
}: HardhatRuntimeEnvironment) {
  const { deploy } = deployments;
  const { deployer, amm1Factory, amm2Factory } = await getNamedAccounts();

  const Roles = await deployments.get('Roles');
  const peg = await deployments.get('Peg');


  const amm1InitHash = amm1InitHashes[await getChainId()];
  const amm2InitHash = amm2InitHashes[await getChainId()];

  console.log(`${amm1InitHashes} ${amm1InitHash}`);

  await deploy('CrossMarginTrading', {
    from: deployer,
    args: [peg.address, amm1Factory, amm2Factory, amm1InitHash, amm2InitHash, Roles.address],
    log: true,
    skipIfAlreadyDeployed: true
  });
};
deploy.tags = ['CrossMarginTrading', 'local'];
deploy.dependencies = ['Roles', 'Peg'];
export default deploy;
