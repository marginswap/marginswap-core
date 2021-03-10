import { task } from "hardhat/config";
import "@nomiclabs/hardhat-waffle";
import * as fs from 'fs';
import 'hardhat-deploy';
import "hardhat-deploy-ethers";

const MFI_ADDRESS = "0xAa4e3edb11AFa93c41db59842b29de64b72E355B";
const LIQUIDITY_TOKEN = "0x9d640080af7c81911d87632a7d09cc4ab6b133ac";

// This is a sample Hardhat task. To learn how to create your own go to
// https://hardhat.org/guides/create-task.html
task("accounts", "Prints the list of accounts", async (args, hre) => {
    const accounts = await hre.ethers.getSigners();

    for (const account of accounts) {
        console.log(account.address);
    }
});

const homedir = require('os').homedir();
const privateKey = fs.readFileSync(`${homedir}/.marginswap-secret`).toString().trim();
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
            blockGasLimit: 12000000
        },
        mainnet: {
            url: infuraUrl('mainnet'),
            accounts: [privateKey]
        },
        kovan: {
            url: infuraUrl('kovan'),
            accounts: [privateKey],
            gas: "auto",
            gasMultiplier: 1.3,
            gasPrice: "auto"
        },
        ropsten: {
            url: infuraUrl('ropsten'),
            accounts: [privateKey]
        }
    },
    solidity: {
        version: "0.8.1",
        settings: {
            optimizer: {
                enabled: true,
                runs: 200000
            }
        }
    },

    // ChainId: {
    //     MAINNET = 1,
    //     ROPSTEN = 3,
    //     RINKEBY = 4,
    //     GÖRLI = 5,
    //     KOVAN = 42
    // },

    namedAccounts: {
        deployer: {
            default: 0
        },
        roles: {
            1: "0xB867ABeF538349bC5156F524cC7743fE07942D3F",
            3: "0x71328517862C481fA7E5Ed39Ffc53fc64c9778e5",
            42: "0x541769D9578645b5477ace873b484FabcAD6D428"
        },
        fund: {
            1: "0x2AF84B57B9c56D630DB60d4F564254975736C47e",
            3: "0x690c6ff4C5DdBAeA4282b109dC145cbA19d13206"
        },
        incentiveDistribution: {
            1: "0x20A4Fc1421D7dBe65036C26682A41434f471AeC5",
            3: "0xEf13Ff3E1749606c11623C8b8064761ba70248e3"
        },
        liquidityMiningReward: {
            1: "0xEfa8122994c742566DB4478d25aD1eC3DF07f477",
            3: "0x2C71Dc2795224184bC80466b4E4A8bC29008eD7f"
        },
        liquidityToken: {
            default: LIQUIDITY_TOKEN,
            3: MFI_ADDRESS,
        }
    }
};
