import { task } from "hardhat/config";
import "@nomiclabs/hardhat-waffle";
import * as fs from 'fs';
import { runDeploy } from './deploy/deploy';



// This is a sample Hardhat task. To learn how to create your own go to
// https://hardhat.org/guides/create-task.html
task("accounts", "Prints the list of accounts", async (args, hre) => {
    const accounts = await hre.ethers.getSigners();

    for (const account of accounts) {
        console.log(account.address);
    }
});

task("deploy", "Runs deployment scripts")
    .addPositionalParam("taskName", "Name of contract or other deployment task to execute")
    .setAction(async (args, hre) => {
        await runDeploy(args.taskName, hre);
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
};
