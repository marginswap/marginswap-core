import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { DeployFunction } from 'hardhat-deploy/types';
import { ethers, network } from 'hardhat';

export type ManagedContract = {
  contractName: string;
  charactersPlayed: number[];
  rolesPlayed: number[];
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
const FEE_RECIPIENT = 110;

const DISABLER = 1001;
const DEPENDENCY_CONTROLLER = 1002;

const managedContracts: ManagedContract[] = [
  {
    contractName: 'Admin',
    charactersPlayed: [ADMIN, FEE_CONTROLLER],
    rolesPlayed: []
  },
  {
    contractName: 'CrossMarginTrading',
    charactersPlayed: [MARGIN_TRADING, PRICE_CONTROLLER],
    rolesPlayed: [WITHDRAWER, AUTHORIZED_FUND_TRADER, BORROWER, STAKE_PENALIZER]
  },
  { contractName: 'Fund', charactersPlayed: [FUND], rolesPlayed: [] },
  {
    contractName: 'Lending',
    charactersPlayed: [LENDING],
    rolesPlayed: [WITHDRAWER, INCENTIVE_REPORTER]
  },
  {
    contractName: 'MarginRouter',
    charactersPlayed: [ROUTER],
    rolesPlayed: [WITHDRAWER, MARGIN_TRADER, BORROWER, INCENTIVE_REPORTER]
  },
  {
    contractName: 'CrossMarginLiquidationV2',
    charactersPlayed: [],
    rolesPlayed: [LIQUIDATOR, MARGIN_TRADER]
  }
];

const deploy: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { getNamedAccounts, deployments, getChainId, getUnnamedAccounts, network } = hre;
  const { deploy } = deployments;
  const { deployer, feeRecipient } = await getNamedAccounts();
  const Roles = await deployments.get('Roles');

  const DependencyController = await deploy('DependencyController', {
    from: deployer,
    args: [Roles.address],
    log: true,
    skipIfAlreadyDeployed: true
  });

  const roles = await ethers.getContractAt('Roles', Roles.address);

  if ((await roles.mainCharacters(DEPENDENCY_CONTROLLER)) != DependencyController.address) {
    const givingRole = await roles.setMainCharacter(DEPENDENCY_CONTROLLER, DependencyController.address, {
      gasLimit: 8000000
    });
    console.log(`Giving dependency controller role: ${givingRole.hash}`);
  }

  if ((await roles.mainCharacters(FEE_RECIPIENT)) != feeRecipient) {
    const dC = await ethers.getContractAt('DependencyController', DependencyController.address);

    const givingRole = await dC.setMainCharacter(FEE_RECIPIENT, feeRecipient, { gasLimit: 8000000 });
    console.log(`Giving fee recipient role: ${givingRole.hash}`);
  }

  for (const mC of managedContracts) {
    await manage(hre, DependencyController.address, mC);
  }
};
deploy.tags = ['DependencyController', 'local'];
deploy.dependencies = managedContracts.map(mc => mc.contractName);
export default deploy;

export async function manage(hre: HardhatRuntimeEnvironment, dcAddress: string, mC: ManagedContract) {
  const contract = await hre.deployments
    .get(mC.contractName)
    .then(C => ethers.getContractAt(mC.contractName, C.address));

  const dC = await ethers.getContractAt('DependencyController', dcAddress);

  const alreadyManaged = await dC.allManagedContracts();
  if (!alreadyManaged.includes(contract.address)) {
    const tx = await dC.manageContract(contract.address, mC.charactersPlayed, mC.rolesPlayed, { gasLimit: 8000000 });
    console.log(`dependencyController.manageContract(${mC.contractName}, ...) tx: ${tx.hash}`);
  }
}
