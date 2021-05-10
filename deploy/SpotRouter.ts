import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { DeployFunction } from 'hardhat-deploy/types';
import { hexlify } from 'ethers/lib/utils';
import { ethers } from 'hardhat';

export const amm1InitHashes = {
  '1': hexlify("0x96e8ac4277198ff8b6f785478aa9a39f403cb768dd02cbee326c3e7da348845f"),
  '31337': hexlify("0x96e8ac4277198ff8b6f785478aa9a39f403cb768dd02cbee326c3e7da348845f"),
  '42': hexlify("0x96e8ac4277198ff8b6f785478aa9a39f403cb768dd02cbee326c3e7da348845f")

}

export const amm2InitHashes = {
  '1': hexlify("0xe18a34eb0e04b04f7a0ac29a6e80748dca96319b42c54d679cb821dca90c6303"),
  '31337': hexlify("0xe18a34eb0e04b04f7a0ac29a6e80748dca96319b42c54d679cb821dca90c6303"),
  '42': hexlify("0xe18a34eb0e04b04f7a0ac29a6e80748dca96319b42c54d679cb821dca90c6303")
}

const deploy: DeployFunction = async function ({
  getNamedAccounts,
  deployments,
  getChainId,
  getUnnamedAccounts,
  network
}: HardhatRuntimeEnvironment) {
  const { deploy } = deployments;

  const { deployer, weth, amm1Factory, amm2Factory } = await getNamedAccounts();

  const amm1InitHash = amm1InitHashes[await getChainId()];
  const amm2InitHash = amm2InitHashes[await getChainId()];
  const SpotRouter = await deploy('SpotRouter', {
    from: deployer,
    args: [weth, amm1Factory, amm2Factory, amm1InitHash, amm2InitHash],
    log: true,
    skipIfAlreadyDeployed: true
  });
};
deploy.tags = ['SpotRouter', 'local'];
deploy.dependencies = [];
export default deploy;
