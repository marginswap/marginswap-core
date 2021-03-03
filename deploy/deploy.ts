import { HardhatRuntimeEnvironment } from "hardhat/types";
import * as deployedAddresses from './deployed-contract-addresses.json';
import * as fs from 'fs';
import { tasks } from "hardhat";
import { Contract } from "ethers";

const ephemeralNetworks = new Set(['hardhat', 'default', 'localhost', undefined, null]);

type DeployRecord = {
    [taskName: string]: string
}

const deployTasks: {
    [task: string]: {
        fun: (deployedAddresses: DeployRecord, hre: HardhatRuntimeEnvironment) => Promise<DeployRecord>,
        dependsOn: string[]
    }
} = {
    roles: {
        fun: deployRoles,
        dependsOn: []
    },
    fund: {
        fun: deployFund,
        dependsOn: ['roles']
    }
}

export async function runDeploy(taskName: string, hre: HardhatRuntimeEnvironment) {
    const currentNetwork = hre.hardhatArguments.network;
    const deployRecord: DeployRecord = deployedAddresses[currentNetwork] || {};
    deployedAddresses[currentNetwork] = await runTask(taskName, deployRecord, hre);
    if (!ephemeralNetworks.has(currentNetwork)) {
        storeAddresses(deployedAddresses);
    }
}

async function runTask(taskName: string,
    deployRecord: DeployRecord,
    hre: HardhatRuntimeEnvironment) {
    if (!deployRecord[taskName]) {
        const task = deployTasks[taskName];
        console.log(`Deploying dependencies for ${taskName}: ${task.dependsOn}`);
        for (let dependencyName of task.dependsOn) {
            deployRecord = {
                ...deployRecord,
                ...await runTask(dependencyName, deployRecord, hre)
            };
        }
        deployRecord = {
            ...deployRecord,
            ...await task.fun(deployRecord, hre)
        }
        console.log(`Finished: ${taskName} at: ${deployRecord[taskName]}`);
    } else {
        console.log(`Already deployed: ${taskName} at: ${deployRecord[taskName]}`);
    }
    return deployRecord;
}

function storeAddresses(addresses: object) {
    fs.writeFile('deployed-contract-addresses.json',
        JSON.stringify(addresses, null, 4), () => { });
}

// outside addresses
const WETH = "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2";
const MFI_ADDRESS = "0xAa4e3edb11AFa93c41db59842b29de64b72E355B";
const REAL_TREASURY = "0x16F3Fc1E4BA9d70f47387b902fa5d21020b5C6B5";
const UNISWAP_FACTORY = "0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f";
const SUSHISWAP_FACTORY = "0xC0AEe478e3658e2610c5F7A4A2E1777cE9e4f2Ac";
const USDC_ADDRESS = "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48";
const LIQUIDITY_TOKEN = "0x9d640080af7c81911d87632a7d09cc4ab6b133ac";

// roles

const WITHDRAWER = 1;
const MARGIN_CALLER = 2;
const BORROWER = 3;
const MARGIN_TRADER = 4;
const FEE_SOURCE = 5;
const LIQUIDATOR = 6;
const AUTHORIZED_FUND_TRADER = 7;
const INCENTIVE_REPORTER = 8;

const FUND = 101;
const LENDING = 102;
const ROUTER = 103;
const MARGIN_TRADING = 104;
const FEE_CONTROLLER = 105;
const PRICE_CONTROLLER = 106;


async function deployRoles(_: DeployRecord, hre: HardhatRuntimeEnvironment) {
    const Roles = await hre.ethers.getContractFactory("Roles");
    const roles = await Roles.deploy();
    await roles.deployed();

    return { roles: roles.address };
}

async function deployFund(deplRec: DeployRecord, hre: HardhatRuntimeEnvironment) {
    const Roles = await hre.ethers.getContractFactory("Roles");
    const roles = await Roles.attach(deplRec.roles);

    const Fund = await hre.ethers.getContractFactory("Fund");
    const fund = await Fund.deploy(WETH, roles.address);
    await fund.deployed();

    const RoleAware = await hre.ethers.getContractFactory("RoleAware");
    roles.functions.setMainCharacter(FUND);

    return { fund: fund.address };
}

