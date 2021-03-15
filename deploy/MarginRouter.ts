import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";

const deploy: DeployFunction = async function ({
    getNamedAccounts,
    deployments,
    getChainId,
    getUnnamedAccounts,
    network,
}: HardhatRuntimeEnvironment) {
    const { deploy } = deployments;
    const { deployer, weth } = await getNamedAccounts();
    const Roles = await deployments.get("Roles");

    await deploy("MarginRouter", {
        from: deployer,
        args: [weth, Roles.address],
    });
};
module.exports.tags = ["MarginRouter", "local"];
module.exports.dependencies = ["Roles"];
export default deploy;
