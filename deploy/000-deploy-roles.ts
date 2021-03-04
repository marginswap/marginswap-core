import { HardhatRuntimeEnvironment } from 'hardhat-deploy/src/type-extensions';
import { DeployFunction } from 'hardhat-deploy/types';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    const { deployments, getNamedAccounts } = hre;
    const { deploy, execute, read, log } = deployments;

    const { deployer } = await getNamedAccounts();

    await deploy('Greeter', {
        from: deployer,
        args: [deployer, 'hello world'],
        log: true,
        deterministicDeployment: true,
    });

    const copyResult = await deploy('Greeter', {
        from: deployer,
        args: [deployer, 'hello world'],
        log: true,
        deterministicDeployment: true,
    });

    const currentGreeting = await read('Greeter', 'greet');
    log({ currentGreeting });

    if (!hre.network.mainnet) {
        await execute(
            'Greeter',
            { from: deployer, log: true },
            'setGreetingThatWorks',
            'hi'
        );
    }
};
export default func;