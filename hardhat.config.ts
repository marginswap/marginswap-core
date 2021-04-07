import { task } from 'hardhat/config';
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
const USDT_ADDRESS = '0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2';

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

task('export-addresses', 'Export deployment addresses to JSON file', async (args, hre) => {
  const addresses = require('./build/addresses');
  const networkAddresses = Object.entries(await hre.deployments.all()).map(
    ([name, deployRecord]: [string, Deployment]) => {
      return [name, deployRecord.address];
    }
  );
  addresses[hre.network.name] = Object.fromEntries(networkAddresses);
  const stringRepresentation = JSON.stringify(addresses, null, 2);
  console.log(addresses);

  fs.writeFileSync('./build/addresses.json', stringRepresentation);
});

task('print-network', 'Print network name', async (args, hre) => console.log(hre.network.name));

const homedir = require('os').homedir();
const privateKey = fs.readFileSync(`${homedir}/.marginswap-secret`).toString().trim();
function infuraUrl(networkName: string) {
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
      }
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
    }
  },
  solidity: {
    version: '0.8.3',
    settings: {
      optimizer: {
        enabled: true,
        // TODO
        runs: 1000
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
      default: MFI_ADDRESS
    },
    lockedMfi: {
      default: LOCKED_MFI
    },
    lockedMfiDelegate: {
      default: MAIN_DEPLOYER
    },
    weth: {
      31337: '0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2',
      1: '0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2',
      42: '0xd0a1e359811322d97991e03f863a0c30c2cf029c'
    },
    usdt: {
      default: USDT_ADDRESS
    }
  }
};
