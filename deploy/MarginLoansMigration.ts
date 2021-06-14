import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { DeployFunction } from 'hardhat-deploy/types';
import { ethers } from 'hardhat';
import contractAddresses from '@marginswap/core-abi/addresses.json';
import MarginRouter from '@marginswap/core-abi/artifacts/contracts/MarginRouter.sol/MarginRouter.json';
import CrossMarginTrading from '@marginswap/core-abi/artifacts/contracts/CrossMarginTrading.sol/CrossMarginTrading.json';
import { BigNumber } from '@ethersproject/bignumber';
import {getMarginAddresses} from './MarginHoldingsMigration';

const MIN_HOLDINGS = 30 * 10 ** 6;

const deploy: DeployFunction = async function ({
  getNamedAccounts,
  deployments,
  getChainId,
  getUnnamedAccounts,
  network
}: HardhatRuntimeEnvironment) {
  const { deploy } = deployments;
  const { deployer, weth } = await getNamedAccounts();

  const DC = await deployments.get('DependencyController');
  const dc = await ethers.getContractAt('DependencyController', DC.address);

  const Roles = await deployments.get('Roles');
  const roles = await ethers.getContractAt('Roles', Roles.address);

  const chainId = network.config.chainId!.toString();
  // const chainId = '1';

  const args = [
    contractAddresses[chainId].CrossMarginTrading,
    ...(await getMarginAccounts(chainId)),
    roles.address
  ];

  console.log('MarginLoansMigration args:');
  console.log(args);

  const Migration = await deploy('MarginLoansMigration', {
    from: deployer,
    args,
    log: true,
    skipIfAlreadyDeployed: true
  });

  // run if it hasn't self-destructed yet
  if ((await ethers.provider.getCode(Migration.address)) !== '0x') {
    console.log(`Executing special migration ${Migration.address} via dependency controller ${dc.address}`);
    const tx = await dc.executeAsOwner(Migration.address);
    console.log(`ran ${Migration.address} as owner, tx: ${tx.hash} with gasLimit: ${tx.gasLimit}`);
  }
};

deploy.tags = ['MarginLoansMigration', 'local'];
deploy.dependencies = ['MarginHoldingsMigration', 'LendingMigration', 'TokenActivation'];
export default deploy;


async function getMarginAccounts(chainId: string) {
  const cmtAddress = contractAddresses[chainId].CrossMarginTrading;
  const cmt = await ethers.getContractAt(CrossMarginTrading.abi, cmtAddress);

  const accountAddresses = await getMarginAddresses(chainId);

  const addresses: string[] = [];
  const tokens: string[] = [];
  const amounts: BigNumber[] = [];

  for (let address of accountAddresses) {
    const [_tokens, _amounts] = await cmt.getBorrowAmounts(address);
    addresses.push(...Array(_tokens.length).fill(address));
    tokens.push(..._tokens);
    amounts.push(..._amounts);
  }

  return [addresses, tokens, amounts];
}
