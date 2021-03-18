import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
const { ethers } = require("hardhat");

const WETH = "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2";
const FUND = 101;
const TOKEN_ACTIVATOR = 9;

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
  const roles = await ethers.getContractAt("Roles", Roles.address);

  const Fund = await deploy("Fund", {
    from: deployer,
    args: [WETH, roles.address],
    skipIfAlreadyDeployed: true,
  });
};
deploy.tags = ["Fund"];
deploy.dependencies = ["Roles", "RoleAware"];
export default deploy;
