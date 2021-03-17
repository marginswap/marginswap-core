import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { ethers } from 'hardhat';

type ManagedContract = {
  contractName: string,
  charactersPlayed: number[],
  rolesPlayed: number[],
  ownAsDelegate?: string[];
};

const WITHDRAWER = 1;
const MARGIN_CALLER = 2;
const BORROWER = 3;
const MARGIN_TRADER = 4;
const FEE_SOURCE = 5;
const LIQUIDATOR = 6;
const AUTHORIZED_FUND_TRADER = 7;
const INCENTIVE_REPORTER = 8;
const TOKEN_ACTIVATOR = 9;
const STAKE_PENALIZER = 10;

const FUND = 101;
const LENDING = 102;
const ROUTER = 103;
const MARGIN_TRADING = 104;
const FEE_CONTROLLER = 105;
const PRICE_CONTROLLER = 106;
const ADMIN = 107;
const INCENTIVE_DISTRIBUTION = 108;

const managedContracts: ManagedContract[] = [
  { contractName: "Admin", charactersPlayed: [ADMIN, FEE_CONTROLLER], rolesPlayed: [] },
  { contractName: "CrossMarginTrading", charactersPlayed: [MARGIN_TRADING], rolesPlayed: [WITHDRAWER, AUTHORIZED_FUND_TRADER, STAKE_PENALIZER] },
  { contractName: "Fund", charactersPlayed: [FUND], rolesPlayed: [] },
  { contractName: "IncentiveDistribution", charactersPlayed: [INCENTIVE_DISTRIBUTION], rolesPlayed: [] },
  { contractName: "Lending", charactersPlayed: [LENDING], rolesPlayed: [WITHDRAWER, INCENTIVE_REPORTER] },
  { contractName: "LiquidityMiningReward", charactersPlayed: [], rolesPlayed: [INCENTIVE_REPORTER] },
  { contractName: "MarginRouter", charactersPlayed: [ROUTER], rolesPlayed: [WITHDRAWER, MARGIN_TRADER, BORROWER, INCENTIVE_REPORTER] },
  { contractName: "TokenAdmin", charactersPlayed: [], rolesPlayed: [TOKEN_ACTIVATOR], ownAsDelegate: ["IncentiveDistribution"] },
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

  const delegation = Promise
    .all((mC.ownAsDelegate || [])
      .map(async (property: string) => (await hre.deployments.get(property)).address));

  await dC.manageContract(contract.address, mC.charactersPlayed, mC.rolesPlayed, delegation);
  await contract.transferOwnership(dC.address);

}