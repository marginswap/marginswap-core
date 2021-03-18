import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";

const USDT_ADDRESS = "0xdac17f958d2ee523a2206206994597c13d831ec7";

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

  await deploy("CrossMarginTrading", {
    from: deployer,
    args: [USDT_ADDRESS, Roles.address],
    skipIfAlreadyDeployed: true,
  });
};
deploy.tags = ["CrossMarginTrading", "local"];
deploy.dependencies = ["Roles"];
export default deploy;
