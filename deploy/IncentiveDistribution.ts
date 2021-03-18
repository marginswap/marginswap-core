import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from 'hardhat-deploy/types';
const { ethers } = require('hardhat');

const MFI_ADDRESS = "0xAa4e3edb11AFa93c41db59842b29de64b72E355B";
const TOKEN_ACTIVATOR = 9;

const deploy: DeployFunction = async function ({
    getNamedAccounts,
    deployments,
    getChainId,
    getUnnamedAccounts,
    network
}: HardhatRuntimeEnvironment) {
    const { deploy } = deployments;
    const { deployer } = await getNamedAccounts();
    const roles = await deployments.get("Roles")
        .then(Roles => ethers.getContractAt("Roles", Roles.address));

    const deployRecord = await deploy('IncentiveDistribution', {
        from: deployer,
        args: [MFI_ADDRESS, 4000, roles.address],
        log: true,
        skipIfAlreadyDeployed: true,
    });
    
    if (deployRecord.newlyDeployed) {
        const fund = await deployments.get("Fund")
            .then(Fund => ethers.getContractAt("Fund", Fund.address));
        await roles.giveRole(TOKEN_ACTIVATOR, deployer);
        await fund.updateRoleCache(TOKEN_ACTIVATOR, deployer);
    
        await fund.activateToken(MFI_ADDRESS);
    }
};

deploy.tags = ['IncentiveDistribution', 'local'];
deploy.dependencies = ['Roles', 'Fund'];
export default deploy