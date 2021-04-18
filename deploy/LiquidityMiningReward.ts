import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { DeployFunction } from 'hardhat-deploy/types';
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
  const { deployer, liquidityToken } = await getNamedAccounts();

  const incentiveDistribution = await deployments
    .get('IncentiveDistribution')
    .then(IncentiveDistribution => ethers.getContractAt('IncentiveDistribution', IncentiveDistribution.address));

  const roles = await deployments.get('Roles').then(Roles => ethers.getContractAt('Roles', Roles.address));
  const nowSeconds = Math.floor(new Date().getTime() / 1000);

  const liquidityMiningReward = await deploy('LiquidityMiningReward', {
    from: deployer,
    args: [roles.address, liquidityToken, nowSeconds],
    log: true,
    skipIfAlreadyDeployed: true
  });
};

deploy.tags = ['LiquidityMiningReward', 'local'];
deploy.dependencies = ['Roles', 'IncentiveDistribution'];
export default deploy;
