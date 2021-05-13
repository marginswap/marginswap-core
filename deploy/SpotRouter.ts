import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { DeployFunction } from 'hardhat-deploy/types';
import { hexlify } from 'ethers/lib/utils';
import { ethers } from 'hardhat';

export const amm1InitHashes = {
  '1': hexlify('0x96e8ac4277198ff8b6f785478aa9a39f403cb768dd02cbee326c3e7da348845f'),
  //'31337': hexlify("0x40231f6b438bce0797c9ada29b718a87ea0a5cea3fe9a771abdd76bd41a3e545"),
  '31337': hexlify('0x96e8ac4277198ff8b6f785478aa9a39f403cb768dd02cbee326c3e7da348845f'),
  '42': hexlify('0x96e8ac4277198ff8b6f785478aa9a39f403cb768dd02cbee326c3e7da348845f'),
  '0xa86a': hexlify('0x40231f6b438bce0797c9ada29b718a87ea0a5cea3fe9a771abdd76bd41a3e545')
};

export const amm2InitHashes = {
  '1': hexlify('0xe18a34eb0e04b04f7a0ac29a6e80748dca96319b42c54d679cb821dca90c6303'),
  //'31337': hexlify("0x81dbf51ab39dc634785936a3b34def28bf8007e6dfa30d4284c4b8547cb47a51"),
  '31337': hexlify('0xe18a34eb0e04b04f7a0ac29a6e80748dca96319b42c54d679cb821dca90c6303'),
  '42': hexlify('0xe18a34eb0e04b04f7a0ac29a6e80748dca96319b42c54d679cb821dca90c6303'),
  '0xa86a': hexlify('0x81dbf51ab39dc634785936a3b34def28bf8007e6dfa30d4284c4b8547cb47a51')
};

const deploy: DeployFunction = async function ({
  getNamedAccounts,
  deployments,
  getChainId,
  getUnnamedAccounts,
  network
}: HardhatRuntimeEnvironment) {
  const { deploy } = deployments;

  const { deployer, baseCurrency, amm1Factory, amm2Factory } = await getNamedAccounts();

  const amm1InitHash = amm1InitHashes[await getChainId()];
  const amm2InitHash = amm2InitHashes[await getChainId()];

  const args = [baseCurrency, amm1Factory, amm2Factory, amm1InitHash, amm2InitHash];
  const SpotRouter = await deploy('SpotRouter', {
    from: deployer,
    args,
    log: true,
    skipIfAlreadyDeployed: true
  });
};
deploy.tags = ['SpotRouter', 'local'];
deploy.dependencies = [];
export default deploy;
