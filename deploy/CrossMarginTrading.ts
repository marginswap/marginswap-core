import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { deployments } from "hardhat";

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
  const peg = await deployments.get("Peg");

  await deploy("CrossMarginTrading", {
    from: deployer,
    args: [peg.address, Roles.address],
    log: true,
    skipIfAlreadyDeployed: true,
  });
};
deploy.tags = ["CrossMarginTrading", "local"];
deploy.dependencies = ["Roles", "Peg"];
export default deploy;
