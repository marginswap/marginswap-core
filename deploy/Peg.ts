import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { deployments } from "hardhat";
import ERC20PresetMinterPauser from "@openzeppelin/contracts/build/contracts/ERC20PresetMinterPauser.json";

const deploy: DeployFunction = async function ({
  getNamedAccounts,
  deployments,
  getChainId,
  getUnnamedAccounts,
  network,
}: HardhatRuntimeEnvironment) {
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  await deploy("Peg", {
    contract: ERC20PresetMinterPauser,
    from: deployer,
    args: ["TestToken", "TT"],
    log: true,
    skipIfAlreadyDeployed: true,
  });
};
deploy.tags = ["Peg", "local"];
export default deploy;
