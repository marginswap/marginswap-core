import { task, subtask } from 'hardhat/config';
import '@nomiclabs/hardhat-waffle';
import * as fs from 'fs';
import 'hardhat-deploy';
import 'hardhat-deploy-ethers';
import { submitSources } from 'hardhat-deploy/dist/src/etherscan';
import path from 'path';
import * as types from 'hardhat/internal/core/params/argumentTypes';
import { Deployment } from 'hardhat-deploy/dist/types';
import 'hardhat-contract-sizer';
import '@nomiclabs/hardhat-solhint';
import ethernal from 'hardhat-ethernal';

import { TASK_NODE, TASK_TEST, TASK_NODE_GET_PROVIDER, TASK_NODE_SERVER_READY } from 'hardhat/builtin-tasks/task-names';
import { HardhatRuntimeEnvironment } from 'hardhat/types';

// ChainIds
const MAINNET = 1;
const ROPSTEN = 3;
const RINKEBY = 4;
const GÖRLI = 5;
const KOVAN = 42;

// outside addresses
const MFI_ADDRESS = '0xAa4e3edb11AFa93c41db59842b29de64b72E355B';
const LOCKED_MFI = '0x6c8fbBf8E079246A92E760D440793f2f864a26b3';
const REAL_TREASURY = '0x16F3Fc1E4BA9d70f47387b902fa5d21020b5C6B5';
const UNISWAP_FACTORY = '0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f';
const SUSHISWAP_FACTORY = '0xC0AEe478e3658e2610c5F7A4A2E1777cE9e4f2Ac';
const USDC_ADDRESS = '0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48';
const LIQUIDITY_TOKEN = '0x9d640080af7c81911d87632a7d09cc4ab6b133ac';
const ROPSTEN_LIQUI_TOKEN = '0xc4c79A0e1C7A9c79f1e943E3a5bEc65396a5434a';
const MAIN_DEPLOYER = '0x23292e9BA8434e59E6BAC1907bA7425211c4DE27';

// roles

const WITHDRAWER = 1;
const MARGIN_CALLER = 2;
const BORROWER = 3;
const MARGIN_TRADER = 4;
const FEE_SOURCE = 5;
const LIQUIDATOR = 6;
const AUTHORIZED_FUND_TRADER = 7;
const INCENTIVE_REPORTER = 8;
const TOKEN_ACTIVATOR = 9;

const FUND = 101;
const LENDING = 102;
const ROUTER = 103;
const MARGIN_TRADING = 104;
const FEE_CONTROLLER = 105;
const PRICE_CONTROLLER = 106;

// This is a sample Hardhat task. To learn how to create your own go to
// https://hardhat.org/guides/create-task.html
task('accounts', 'Prints the list of accounts', async (args, hre) => {
  const accounts = await hre.ethers.getSigners();

  for (const account of accounts) {
    console.log(account.address);
  }
});

task('custom-etherscan', 'submit contract source code to etherscan')
  .addOptionalParam('apikey', 'etherscan api key', undefined, types.string)
  .addFlag(
    'solcInput',
    'fallback on solc-input (useful when etherscan fails on the minimum sources, see https://github.com/ethereum/solidity/issues/9573)'
  )
  .setAction(async (args, hre) => {
    const etherscanApiKey = args.apiKey || process.env.ETHERSCAN_API_KEY;
    if (!etherscanApiKey) {
      throw new Error(
        `No Etherscan API KEY provided. Set it through comand line option or by setting the "ETHERSCAN_API_KEY" env variable`
      );
    }

    const solcInputsPath = path.join(hre.config.paths.deployments, hre.network.name, 'solcInputs');

    await submitSources(hre, solcInputsPath, {
      etherscanApiKey,
      license: 'None',
      fallbackOnSolcInput: args.solcInput,
      forceLicense: true
    });
  });

task('list-deployments', 'List all the deployed contracts for a network', async (args, hre) => {
  console.log(`All deployments on ${hre.network.name}:`);
  for (const [name, deployment] of Object.entries(await hre.deployments.all())) {
    console.log(`${name}: ${deployment.address}`);
  }
});

async function exportAddresses(args, hre: HardhatRuntimeEnvironment) {
  let addresses: Record<string, string> = {};
  const addressesPath = path.join(__dirname, './build/addresses.json');
  if (fs.existsSync(addressesPath)) {
    addresses = JSON.parse((await fs.promises.readFile(addressesPath)).toString());
  }
  const networkAddresses = Object.entries(await hre.deployments.all()).map(
    ([name, deployRecord]: [string, Deployment]) => {
      return [name, deployRecord.address];
    }
  );
  addresses[await hre.getChainId()] = Object.fromEntries(networkAddresses);
  const stringRepresentation = JSON.stringify(addresses, null, 2);

  await fs.promises.writeFile(addressesPath, stringRepresentation);
  console.log(`Wrote ${addressesPath}. New state:`);
  console.log(addresses);
}

task('export-addresses', 'Export deployment addresses to JSON file', exportAddresses);

subtask(TASK_NODE_SERVER_READY).setAction(async (args, hre, runSuper) => {
  await runSuper(args);
  await exportAddresses(args, hre);
});

task('print-network', 'Print network name', async (args, hre) => console.log(hre.network.name));

const homedir = require('os').homedir();
const privateKey = fs.readFileSync(`${homedir}/.marginswap-secret`).toString().trim();
function infuraUrl(networkName: string) {
  // return `https://eth-${networkName}.alchemyapi.io/v2/AcIJPH41nagmF3o1sPArEns8erN9N691`;
   return `https://${networkName}.infura.io/v3/ae52aea5aa2b41e287d72e10b1175491`;
}

/**
 * @type import('hardhat/config').HardhatUserConfig
 */
export default {
  paths: {
    artifacts: './build/artifacts'
  },
  defaultNetwork: 'hardhat',
  networks: {
    hardhat: {
      blockGasLimit: 12000000,
      forking: {
        url: infuraUrl('mainnet')
        // url: 'https://api.avax.network/ext/bc/C/rpc'
      },
      // mining: {
      //   auto: false,
      //   interval: 20000
      // },
      accounts: [{ privateKey, balance: '10000168008000000000000' }]
    },
    mainnet: {
      url: infuraUrl('mainnet'),
      accounts: [privateKey]
    },
    kovan: {
      url: infuraUrl('kovan'),
      accounts: [privateKey],
      gas: 'auto',
      gasMultiplier: 1.3,
      gasPrice: 'auto'
    },
    ropsten: {
      url: infuraUrl('ropsten'),
      accounts: [privateKey]
    },
    avalanche: {
      url: 'https://api.avax.network/ext/bc/C/rpc',
      accounts: [privateKey],
      blockGasLimit: 12000000,
      gasPrice: 'auto'
    },
    matic: {
      // url: 'https://rpc-mainnet.maticvigil.com/v1/b0858bc7aa27b1333df19546c12718235bd11785',
      url: 'https://sparkling-icy-breeze.matic.quiknode.pro/53a1956ec39dddb5ab61f857eed385722d8349bc/',
      // url: 'https://matic-mainnet-full-rpc.bwarelabs.com',
      accounts: [privateKey],
      // gasPrice: 1000000000
    },
    bsc: {
      url: "https://bsc-dataseed.binance.org/",
      chainId: 56,
      accounts: [privateKey]
    }
  },
  solidity: {
    version: '0.8.3',
    settings: {
      optimizer: {
        enabled: true,
        // TODO
        runs: 200
      }
    }
  },
  namedAccounts: {
    deployer: {
      default: 0
    },
    liquidityToken: {
      default: LIQUIDITY_TOKEN,
      3: ROPSTEN_LIQUI_TOKEN
    },
    mfiAddress: {
      43114: '0x9fda7ceec4c18008096c2fe2b85f05dc300f94d0',
      1: MFI_ADDRESS,
      42: MFI_ADDRESS,
      31337: MFI_ADDRESS,
      137: '0x7Bc429a2fA7d71C4693424FDcaB5a2521b9FD343',
      56: '0x37bdfd6ed491ee0e0fe2ce49de2cb573880e3734'
    },
    feeRecipient: {
      default: MAIN_DEPLOYER,
      43114: '0xBaF3c8431979e10A3204F2DBF5DAb205923B3220'
    },
    lockedMfi: {
      default: LOCKED_MFI
    },
    lockedMfiDelegate: {
      default: MAIN_DEPLOYER
    },
    baseCurrency: {
      31337: '0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2',
      //31337: '0xB31f66AA3C1e785363F0875A1B74E27b85FD66c7',
      1: '0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2',
      42: '0xd0a1e359811322d97991e03f863a0c30c2cf029c',
      '43114': '0xB31f66AA3C1e785363F0875A1B74E27b85FD66c7',
      137: '0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270',
      56: '0xbb4cdb9cbd36b01bd1cbaebf2de08d9173bc095c',
    },
    dai: {
      1: '0x6b175474e89094c44da98b954eedeac495271d0f',
      31337: '0x6b175474e89094c44da98b954eedeac495271d0f',
      42: '0x4f96fe3b7a6cf9725f59d353f723c1bdb64ca6aa',
      default: '0x6b175474e89094c44da98b954eedeac495271d0f'
    },
    usdc: {
      default: '0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48'
    },
    usdt: {
      1: '0xdAC17F958D2ee523a2206206994597C13D831ec7',
      31337: '0xdAC17F958D2ee523a2206206994597C13D831ec7',
      //31337: '0xde3A24028580884448a5397872046a019649b084',
      '43114': '0xc7198437980c041c805A1EDcbA50c1Ce5db95118',
      137: '0xc2132D05D31c914a87C6611C10748AEb04B58e8F',
      56: '0x55d398326f99059ff775485246999027b3197955'
    },
    amm1Factory: {
      default: '0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f',
      //31337: "0xefa94DE7a4656D787667C749f7E1223D71E9FD88",
      42: '0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f',
      '43114': '0xefa94DE7a4656D787667C749f7E1223D71E9FD88',
      137: '0x5757371414417b8C6CAad45bAeF941aBc7d3Ab32',
      56: '0xcA143Ce32Fe78f1f7019d7d551a6402fC5350c73'
    },
    amm2Factory: {
      default: '0xC0AEe478e3658e2610c5F7A4A2E1777cE9e4f2Ac',
      //31337: "0xBB6e8C136ca537874a6808dBFC5DaebEd9a57554",
      42: '0xC0AEe478e3658e2610c5F7A4A2E1777cE9e4f2Ac',
      '43114': '0x9Ad6C38BE94206cA50bb0d90783181662f0Cfa10',
      137: '0xc35DADB65012eC5796536bD9864eD8773aBc74C4',
      56: '0x0841BD0B734E4F5853f0dD8d7Ea041c241fb0Da6'
    },
    amm3Factory: {
      1: '0x0000000000000000000000000000000000000000',
      31337: '0x0000000000000000000000000000000000000000',
      '43114': '0xc35DADB65012eC5796536bD9864eD8773aBc74C4',
      137: '0xE7Fb3e833eFE5F9c441105EB65Ef8b261266423B',
      56: '0x0000000000000000000000000000000000000000'
    }
  }
};
