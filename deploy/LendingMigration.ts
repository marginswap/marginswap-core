import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { DeployFunction } from 'hardhat-deploy/types';
import { ethers } from 'hardhat';
import contractAddresses from '@marginswap/core-abi/addresses.json';
import Lending from '@marginswap/core-abi/artifacts/contracts/Lending.sol/Lending.json';
import IncentiveReporter from '@marginswap/core-abi/artifacts/libraries/IncentiveReporter.sol/IncentiveReporter.json';
import { BigNumber } from '@ethersproject/bignumber';

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
    contractAddresses[chainId].Lending,
    ...(await getLendingAccounts(chainId)),
    roles.address
  ];

  console.log('LendingMigration args:');
  console.log(args);

  const Migration = await deploy('LendingMigration', {
    from: deployer,
    args,
    log: true,
    skipIfAlreadyDeployed: true
  });

  // run if it hasn't self-destructed yet
  if ((await ethers.provider.getCode(Migration.address)) !== '0x') {
    console.log(`Executing special migration ${Migration.address} via dependency controller ${dc.address}`);
    const tx = await dc.executeAsOwner(Migration.address);
    console.log(`ran ${Migration.address} as owner, tx: ${tx.hash} with ${tx.gasLimit} gas limit`);
  }
};

deploy.tags = ['LendingMigration', 'local'];
deploy.dependencies = ['TokenActivation'];
export default deploy;

async function getLendingAccounts(chainId: string) {
  const lendingAddress = contractAddresses[chainId].Lending;
  const lending = await ethers.getContractAt(Lending.abi, lendingAddress);
  const incentiveReporter = await ethers.getContractAt(IncentiveReporter.abi, lendingAddress);

  const topic = ethers.utils.id('AddToClaim(address,address,uint256)');
  const events = await incentiveReporter
    .queryFilter({
      address: lendingAddress,
      topics: [topic]
    }, 1000, 'latest');

  const addresses: string[] = [];
  const tokens: string[] = [];
  const amounts: BigNumber[] = [];
  const extantPairs: Set<string> = new Set();

  for (const event of events) {
    const token = event.args[0];
    const address = event.args[1];

    const joined = `${token}-${address}`;
    const amount = await lending.viewHourlyBondAmount(token, address);
    if (!extantPairs.has(joined) && amount.gt(10 ** 7)) {
      extantPairs.add(joined);

      tokens.push(token);
      addresses.push(address);
      amounts.push(amount);  
    }
  }

  return [addresses, tokens, amounts];
}
