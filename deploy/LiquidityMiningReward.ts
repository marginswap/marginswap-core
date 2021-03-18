import { HardhatRuntimeEnvironment } from "hardhat/types";
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
    const incentiveDistribution = await deployments.get("IncentiveDistribution")
        .then(IncentiveDistribution => ethers.getContractAt("IncentiveDistribution", IncentiveDistribution.address));
    const roles = await deployments.get("Roles")
        .then(Roles => ethers.getContractAt("Roles", Roles.address));
    const nowSeconds = Math.floor(new Date().getTime() / 1000);

    const liquidityMiningReward = await deploy('LiquidityMiningReward', {
        from: deployer,
        args: [incentiveDistribution.address, liquidityToken, nowSeconds],
        log: true,
        skipIfAlreadyDeployed: true,
    });

    roles.giveRole(INCENTIVE_REPORTER, liquidityMiningReward.address)
    await incentiveDistribution.initTranche(
        0, // tranche id
        200 // share of pie in permil
    )
};

deploy.tags = ['LiquidityMiningReward', 'local'];
deploy.dependencies = ['IncentiveDistribution'];
export default deploy