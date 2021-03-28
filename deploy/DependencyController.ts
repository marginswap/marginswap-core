import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { ethers, network } from 'hardhat';

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
const TOKEN_ADMIN = 109;

const managedContracts: ManagedContract[] = [
  { contractName: "Admin", charactersPlayed: [ADMIN, FEE_CONTROLLER], rolesPlayed: [] },
  { contractName: "CrossMarginTrading", charactersPlayed: [MARGIN_TRADING, BORROWER], rolesPlayed: [WITHDRAWER, AUTHORIZED_FUND_TRADER, STAKE_PENALIZER] },
  { contractName: "Fund", charactersPlayed: [FUND], rolesPlayed: [] },
  { contractName: "IncentiveDistribution", charactersPlayed: [INCENTIVE_DISTRIBUTION], rolesPlayed: [] },
  { contractName: "Lending", charactersPlayed: [LENDING], rolesPlayed: [WITHDRAWER, INCENTIVE_REPORTER] },
  { contractName: "LiquidityMiningReward", charactersPlayed: [], rolesPlayed: [INCENTIVE_REPORTER] },
  { contractName: "MarginRouter", charactersPlayed: [ROUTER], rolesPlayed: [WITHDRAWER, MARGIN_TRADER, BORROWER, INCENTIVE_REPORTER] },
  { contractName: "TokenAdmin", charactersPlayed: [TOKEN_ADMIN], rolesPlayed: [TOKEN_ACTIVATOR], ownAsDelegate: ["IncentiveDistribution"] },
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
    log: true,
    skipIfAlreadyDeployed: true,
  });

  const roles = await ethers.getContractAt("Roles", Roles.address);

  if ((await roles.owner()) != DependencyController.address) {
    const tx = await roles.transferOwnership(DependencyController.address);
    console.log(`roles.transferOwnership tx: ${tx.hash}`);
  }

  const IncentiveDistribution = await deployments.get("IncentiveDistribution");
  const incentiveDistribution = await ethers
    .getContractAt("IncentiveDistribution", IncentiveDistribution.address);

  const incentiveOwner = await incentiveDistribution.owner(); 
  if (incentiveOwner !== DependencyController.address && incentiveOwner !== (await deployments.get("TokenAdmin")).address) {
    const tx = await incentiveDistribution.transferOwnership(DependencyController.address);
    console.log(`incentiveDistribution.transferOwnership tx: ${tx.hash}`);
  }

  for (const mC of managedContracts) {
    await manage(hre, DependencyController.address, mC);
  }

  // if (!network.live) {
  //   const dC = await ethers.getContractAt("DependencyController", DependencyController.address);
  //   const tx = await dC.relinquishOwnership(roles.address, deployer);
  //   console.log(`dependencyController.relinquishOwnership tx: ${tx.hash}`);
  // }
};
deploy.tags = ["DependencyController", "local"];
deploy.dependencies = managedContracts.map(mc => mc.contractName);
export default deploy;


async function manage(hre: HardhatRuntimeEnvironment, dcAddress: string, mC: ManagedContract) {
  const contract = await hre.deployments.get(mC.contractName)
    .then(C => ethers.getContractAt(mC.contractName, C.address));

  const dC = await ethers.getContractAt("DependencyController", dcAddress);

  const currentOwner = await contract.owner();
  const { deployer }  = await hre.getNamedAccounts();
  const needsOwnershipUpdate = currentOwner !== dC.address && currentOwner === deployer;

  if (needsOwnershipUpdate) {
    const tx = await contract.transferOwnership(dC.address);
    console.log(`${mC.contractName}.transferOwnership to dependencyController tx: ${tx.hash}`);
  } else if(currentOwner !== dcAddress) {
    console.warn(`${mC.contractName} is owned by ${currentOwner}, not dependency controller ${dcAddress}`);
    console.log(`(current deployer address is ${deployer})`);
  }

  const alreadyManaged = await dC.allManagedContracts();
  if (!alreadyManaged.includes(contract.address)) {
    const delegation = await Promise
      .all((mC.ownAsDelegate || [])
        .map(async (property: string) => (await hre.deployments.get(property)).address));

    if (mC.contractName != "LiquidityMiningReward") {
      const tx = await dC.manageContract(contract.address, mC.charactersPlayed, mC.rolesPlayed, delegation);
      console.log(`dependencyController.manageContract(${mC.contractName}, ...) tx: ${tx.hash}`);
    }
  }
}
