import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from 'hardhat-deploy/types';

const FEES_PER_10K = 10;

const deploy: DeployFunction = async function ({
    getNamedAccounts,
    deployments,
    getChainId,
    getUnnamedAccounts,
    network
}: HardhatRuntimeEnvironment) {
    const { deploy } = deployments;
    const { deployer, mfiAddress, lockedMfi, lockedMfiDelegate } = await getNamedAccounts();
    const Roles = await deployments.get("Roles");

    await deploy('Admin', {
        from: deployer,
        args: [FEES_PER_10K, mfiAddress, lockedMfi, lockedMfiDelegate, Roles.address],
        log: true,
    });
};
module.exports.tags = ['Admin', 'local'];
module.exports.dependencies = ["Roles"];
export default deploy