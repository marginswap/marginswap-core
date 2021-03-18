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
    const { deployer } = await getNamedAccounts();
    const Roles = await deployments.get("Roles");

    await deploy("Lending", {
        from: deployer,
        args: [Roles.address],
        skipIfAlreadyDeployed: true,
    });
};
deploy.tags = ["Lending", "local"];
deploy.dependencies = ["Roles"];
export default deploy;
