import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { ethers } from 'hardhat';

type ManagedContract = {
  contractName: string,
  charactersPlayed: number[],
  rolesPlayed: number[],
  ownAsDelegate?: string[];
};

const managedContracts: ManagedContract[] = [
];

const deploy: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const {
    getNamedAccounts,
    deployments,
    getChainId,
    getUnnamedAccounts,
    network,
  } = hre;
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();
  const Roles = await deployments.get("Roles");

  const DependencyController = await deploy("DependencyController", {
    from: deployer,
    args: [Roles.address],
  });

  managedContracts.forEach((mC) => {
    manage(hre, DependencyController.address, mC);
  });

  const roles = await ethers.getContractAt("Roles", Roles.address);
  roles.transferOwnership(DependencyController.address);
};
module.exports.tags = ["DependencyController", "local"];
module.exports.dependencies = ["Roles"];
export default deploy;


async function manage(hre: HardhatRuntimeEnvironment, dcAddress: string, mC: ManagedContract) {
  const contract = await hre.deployments.get(mC.contractName)
    .then(C => ethers.getContractAt(mC.contractName, C.address));
  const dC = await ethers.getContractAt("DependencyController", dcAddress);

  await dC.manageContract(contract.address, mC.charactersPlayed, mC.rolesPlayed, mC.ownAsDelegate || []);
  await contract.transferOwnership(dC.address);

}