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
    skipIfAlreadyDeployed: true,
    deterministicDeployment: true
  });

  // if (Admin.newlyDeployed) {
  //   const incentiveDistribution = await deployments
  //     .get('IncentiveDistribution')
  //     .then(IncentiveDistribution => ethers.getContractAt('IncentiveDistribution', IncentiveDistribution.address));
  //   const tx = await incentiveDistribution.initTranche(
  //     1, // tranche id
  //     100 // share of pie in permil
  //   );
  //   console.log(`incentiveDistribution.initTranche: ${tx.hash}`);
  // }
};
deploy.tags = ['Admin', 'local'];
deploy.dependencies = ['Roles', 'IncentiveDistribution'];
export default deploy;
