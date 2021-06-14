import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { DeployFunction } from 'hardhat-deploy/types';
import { ethers } from 'hardhat';
import contractAddresses from '@marginswap/core-abi/addresses.json';
import MarginRouter from '@marginswap/core-abi/artifacts/contracts/MarginRouter.sol/MarginRouter.json';
import CrossMarginTrading from '@marginswap/core-abi/artifacts/contracts/CrossMarginTrading.sol/CrossMarginTrading.json';
import { Seq } from 'immutable';
import { BigNumber } from '@ethersproject/bignumber';

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

  // const chainId = network.config.chainId!.toString();
  const chainId = '1';

  const args = [
    ethers.utils.hexZeroPad('0x00', 20),
    ...(await getMarginAccounts(chainId)),
    roles.address
  ];


  console.log('MarginHoldingsMigration args:');
  console.log(args);

  const Migration = await deploy('MarginHoldingsMigration', {
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

deploy.tags = ['MarginHoldingsMigration', 'local'];
deploy.dependencies = ['TokenActivation'];
export default deploy;


async function getMarginAccounts(chainId: string) {
  const cmtAddress = contractAddresses[chainId].CrossMarginTrading;
  const cmt = await ethers.getContractAt(CrossMarginTrading.abi, cmtAddress);

  const accountAddresses = await getMarginAddresses(chainId);

  const addresses: string[] = [];
  const tokens: string[] = [];
  const amounts: BigNumber[] = [];

  for (let address of accountAddresses) {
    const [_tokens, _amounts] = await cmt.getHoldingAmounts(address);

    addresses.push(...Array(_tokens.length).fill(address));
    tokens.push(..._tokens);
    amounts.push(..._amounts);
  }

  return [addresses, tokens, amounts];
}

export async function getMarginAddresses(chainId: string) {
  const marginRouterAddress = contractAddresses[chainId].MarginRouter;
  const cmtAddress = contractAddresses[chainId].CrossMarginTrading;

  const router = await ethers.getContractAt(MarginRouter.abi, marginRouterAddress);
  const cmt = await ethers.getContractAt(CrossMarginTrading.abi, cmtAddress);

  const topic = ethers.utils.id('AccountUpdated(address)');
  const events = await router
    .queryFilter({
      address: marginRouterAddress,
      topics: [topic]
    }, 1000, 'latest');

  const addresses: string[] = Seq(events).map(event => event.args?.trader).toSet().toArray();

  const result: string[] = [];
  for (const account of addresses) {
    const holdings = await cmt.viewHoldingsInPeg(account);
    if (holdings.gt(MIN_HOLDINGS)) {
      result.push(account);
    }
  }
  return result;
}