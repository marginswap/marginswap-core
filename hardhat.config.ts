import { task } from "hardhat/config";
import "@nomiclabs/hardhat-waffle";
import * as fs from "fs";
import "hardhat-deploy";
import "hardhat-deploy-ethers";

// ChainIds
const MAINNET = 1;
const ROPSTEN = 3;
const RINKEBY = 4;
const GÖRLI = 5;
const KOVAN = 42;

// outside addresses
const WETH = "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2";
const MFI_ADDRESS = "0xAa4e3edb11AFa93c41db59842b29de64b72E355B";
const LOCKED_MFI = "0x6c8fbBf8E079246A92E760D440793f2f864a26b3";
const REAL_TREASURY = "0x16F3Fc1E4BA9d70f47387b902fa5d21020b5C6B5";
const UNISWAP_FACTORY = "0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f";
const SUSHISWAP_FACTORY = "0xC0AEe478e3658e2610c5F7A4A2E1777cE9e4f2Ac";
const USDC_ADDRESS = "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48";
const LIQUIDITY_TOKEN = "0x9d640080af7c81911d87632a7d09cc4ab6b133ac";
const ROPSTEN_LIQUI_TOKEN = "0xc4c79A0e1C7A9c79f1e943E3a5bEc65396a5434a";

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
task("accounts", "Prints the list of accounts", async (args, hre) => {
  const accounts = await hre.ethers.getSigners();

  for (const account of accounts) {
    console.log(account.address);
  }
});

const homedir = require("os").homedir();
const privateKey = fs
  .readFileSync(`${homedir}/.marginswap-secret`)
  .toString()
  .trim();
function infuraUrl(networkName: string) {
  return `https://${networkName}.infura.io/v3/ae52aea5aa2b41e287d72e10b1175491`;
}

/**
 * @type import('hardhat/config').HardhatUserConfig
 */
export default {
  defaultNetwork: "hardhat",
  networks: {
    hardhat: {
      blockGasLimit: 12000000,
    },
    mainnet: {
      url: infuraUrl("mainnet"),
      accounts: [privateKey],
    },
    kovan: {
      url: infuraUrl("kovan"),
      accounts: [privateKey],
      gas: "auto",
      gasMultiplier: 1.3,
      gasPrice: "auto",
    },
    ropsten: {
      url: infuraUrl("ropsten"),
      accounts: [privateKey],
    },
  },
  solidity: {
    version: "0.8.1",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200000,
      },
    },
  },
  namedAccounts: {
    deployer: {
      default: 0,
    },
    roles: {
      1: "0xB867ABeF538349bC5156F524cC7743fE07942D3F",
      3: "0x71328517862C481fA7E5Ed39Ffc53fc64c9778e5",
      42: "0x541769D9578645b5477ace873b484FabcAD6D428",
    },
    fund: {
      1: "0x2AF84B57B9c56D630DB60d4F564254975736C47e",
      3: "0x690c6ff4C5DdBAeA4282b109dC145cbA19d13206",
    },
    incentiveDistribution: {
      1: "0x20A4Fc1421D7dBe65036C26682A41434f471AeC5",
      3: "0xEf13Ff3E1749606c11623C8b8064761ba70248e3",
    },
    liquidityMiningReward: {
      1: "0xEfa8122994c742566DB4478d25aD1eC3DF07f477",
      3: "0x2C71Dc2795224184bC80466b4E4A8bC29008eD7f",
    },
    liquidityToken: {
      default: LIQUIDITY_TOKEN,
      3: MFI_ADDRESS,
    },
    mfiAddress: {
      default: MFI_ADDRESS
    },
    lockedMfi: {
      default: LOCKED_MFI
    },
    lockedMfiDelegate: {
      default: 1
    },
    weth: {
      default: WETH
    }
  },
};
