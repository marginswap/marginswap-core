import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from 'hardhat-deploy/types';
const { ethers } = require('hardhat');

const WETH = "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2";
const FUND = 101;
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
    const Roles = await deployments.get("Roles");
    const roles = await ethers.getContractAt("Roles", Roles.address);

    const Fund = await deploy('Fund', {
        from: deployer,
        args: [WETH, roles.address]
    });
    const fund = await ethers.getContractAt("Fund", Fund.address);

    await roles.setMainCharacter(FUND, fund.address);
    await roles.giveRole(TOKEN_ACTIVATOR, deployer);
    await fund.updateRoleCache(TOKEN_ACTIVATOR, deployer);
};
module.exports.tags = ['Fund'];
module.exports.dependencies = ['Roles', 'RoleAware'];
export default deploy