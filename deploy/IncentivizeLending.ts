
import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { DeployFunction } from 'hardhat-deploy/types';
import { ethers } from 'hardhat';
import { tokensPerNetwork } from './TokenActivation';
import { BigNumber } from 'ethers';
import _ from 'underscore';

const weightsPerNetwork = {
    matic: {
        USDC: 3,
        DAI: 2,
        WETH: 2,
        WMATIC: 2
    },
    mainnet: {
        USDT: 3,
        USDC: 3,
        DAI: 2,
        WBTC: 2,
        WETH: 2
    },
    localhost: {
        USDT: 3,
        USDC: 3,
        DAI: 2,
        WBTC: 2,
        WETH: 2
    },
    avalanche: {
        PNG: 3,
        USDT: 4,
        ETH: 2,
        WAVAX: 2
    }
}

const totalPerNetwork = {
    matic: ethers.utils.parseEther('15000'),
    mainnet: ethers.utils.parseEther('25000'),
    localhost: ethers.utils.parseEther('25000'),
    avalanche: ethers.utils.parseEther('75000')
}

const DISTRIBUTION_MONTHS = 3;

const deploy: DeployFunction = async function ({
    getNamedAccounts,
    deployments,
    getChainId,
    getUnnamedAccounts,
    network
  }: HardhatRuntimeEnvironment) {
    const { deploy, all } = deployments;
    const { deployer } = await getNamedAccounts();

    const Roles = await deployments.get('Roles');
    const roles = await ethers.getContractAt('Roles', Roles.address);

    const DependencyController = await deployments.get('DependencyController');
    const dc = await ethers.getContractAt('DependencyController', DependencyController.address);

    const total = totalPerNetwork[network.name];
    const weights:Record<string,number> = weightsPerNetwork[network.name];
    if (total && weights) {
        const tokens = Object.keys(weights).map((k) => tokensPerNetwork[network.name][k]);
        const totalWeights = Object.values(weights).reduce((a:number, b:number) => a + b);
        const amounts = Object.keys(weights).map((k) => total.mul(weights[k]).div(totalWeights));
        const endTimestamp = Math.floor(Date.now() / 1000) + (DISTRIBUTION_MONTHS * 30 * 24 * 60 * 60)

        const keys = Object.keys(weights);
        for (let i = 0; amounts.length > i; i++) {
            console.log(`${keys[i]}: ${ethers.utils.formatEther(amounts[i])}`);
        }

        console.log("Incentivize lending args:")
        const args = [tokens, amounts, endTimestamp, Roles.address];
        console.log(args);

        const Job = await deploy('IncentivizeLending', {
            from: deployer,
            args,
            log: true,
            skipIfAlreadyDeployed: true,
            
        });

        // run if it hasn't self-destructed yet
        if ((await ethers.provider.getCode(Job.address)) !== '0x') {
            console.log(`Executing lending incentive ${Job.address} via dependency controller ${dc.address}`);
            const tx = await dc.executeAsOwner(Job.address, { gasLimit: 8000000 });
            console.log(`ran ${Job.address} as owner, tx: ${tx.hash} with gasLimit: ${tx.gasLimit}`);
        }
    }
};
deploy.tags = ['IncentivizeLending', 'local'];
deploy.dependencies = ['Roles', 'DependencyController'];
deploy.runAtTheEnd = true;
export default deploy;
  
