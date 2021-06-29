import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { DeployFunction } from 'hardhat-deploy/types';
import { hexlify } from 'ethers/lib/utils';

export const amm1InitHashes = {
  '1': hexlify('0x96e8ac4277198ff8b6f785478aa9a39f403cb768dd02cbee326c3e7da348845f'),
  //'31337': hexlify("0x40231f6b438bce0797c9ada29b718a87ea0a5cea3fe9a771abdd76bd41a3e545"),
  '31337': hexlify('0x96e8ac4277198ff8b6f785478aa9a39f403cb768dd02cbee326c3e7da348845f'),
  '42': hexlify('0x96e8ac4277198ff8b6f785478aa9a39f403cb768dd02cbee326c3e7da348845f'),
  '43114': hexlify('0x40231f6b438bce0797c9ada29b718a87ea0a5cea3fe9a771abdd76bd41a3e545'),
  137: hexlify('0x96e8ac4277198ff8b6f785478aa9a39f403cb768dd02cbee326c3e7da348845f'),
  56: hexlify('0x00fb7f630766e6a796048ea87d01acd3068e8ff67d078148a3fa3f4a84f69bd5')
};

export const amm2InitHashes = {
  '1': hexlify('0xe18a34eb0e04b04f7a0ac29a6e80748dca96319b42c54d679cb821dca90c6303'),
  //'31337': hexlify("0x81dbf51ab39dc634785936a3b34def28bf8007e6dfa30d4284c4b8547cb47a51"),
  '31337': hexlify('0xe18a34eb0e04b04f7a0ac29a6e80748dca96319b42c54d679cb821dca90c6303'),
  '42': hexlify('0xe18a34eb0e04b04f7a0ac29a6e80748dca96319b42c54d679cb821dca90c6303'),
  '43114': hexlify('0xe18a34eb0e04b04f7a0ac29a6e80748dca96319b42c54d679cb821dca90c6303'),
  137: hexlify('0xe18a34eb0e04b04f7a0ac29a6e80748dca96319b42c54d679cb821dca90c6303'),
  56: hexlify('0xf4ccce374816856d11f00e4069e7cada164065686fbef53c6167a63ec2fd8c5b')

};

export const amm3InitHashes = {
  1: hexlify('0x0000000000000000000000000000000000000000000000000000000000000000'),
  31337: hexlify('0x0000000000000000000000000000000000000000000000000000000000000000'),
  43114: hexlify('0x81dbf51ab39dc634785936a3b34def28bf8007e6dfa30d4284c4b8547cb47a51'),
  137: hexlify('0xf187ed688403aa4f7acfada758d8d53698753b998a3071b06f1b777f4330eaf3'),
  56: hexlify('0x0000000000000000000000000000000000000000000000000000000000000000'),
};

const feeBases = {
  56: 9975
}

export function getFeeBase(chainId) {
  return feeBases[chainId] ?? 9970;
}

const deploy: DeployFunction = async function ({
  getNamedAccounts,
  deployments,
  getChainId,
  getUnnamedAccounts,
  network
}: HardhatRuntimeEnvironment) {
  const { deploy } = deployments;

  const { deployer, baseCurrency, amm1Factory, amm2Factory, amm3Factory } = await getNamedAccounts();

  const amm1InitHash = amm1InitHashes[await getChainId()];
  const amm2InitHash = amm2InitHashes[await getChainId()];
  const amm3InitHash = amm3InitHashes[await getChainId()];

  const args = [baseCurrency, amm1Factory, amm2Factory, amm3Factory, amm1InitHash, amm2InitHash, amm3InitHash, getFeeBase(await getChainId())];
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
