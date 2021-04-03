import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { ethers } from "hardhat";
import { getCreate2Address } from '@ethersproject/address';
import { pack, keccak256 } from '@ethersproject/solidity'


const USDT_ADDRESS = "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2";
const MFI_ADDRESS = "0xAa4e3edb11AFa93c41db59842b29de64b72E355B";
const TOKEN_ACTIVATOR = 9;


const UNI_FACTORY_ADDRESS = '0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f'

const UNI_INIT_CODE_HASH = '0x96e8ac4277198ff8b6f785478aa9a39f403cb768dd02cbee326c3e7da348845f'


const tokensPerNetwork = {
  kovan: {
    DAI: "0x4f96fe3b7a6cf9725f59d353f723c1bdb64ca6aa",
    WETH: "0xd0a1e359811322d97991e03f863a0c30c2cf029c",
    UNI: "0x1f9840a85d5af5bf1d1762f925bdaddc4201f984",
    MKR: "0xac94ea989f6955c67200dd67f0101e1865a560ea",
    USDT: USDT_ADDRESS
  },
  mainnet: {
    DAI: "0x6b175474e89094c44da98b954eedeac495271d0f",
    WETH: "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2",
    UNI: "0x1f9840a85d5af5bf1d1762f925bdaddc4201f984",
    MKR: "0x9f8f72aa9304c8b593d555f12ef6589cc3a579a2",
    USDT: USDT_ADDRESS,
  },
  local: {

  }
};

type TokenInitRecord = {
  exposureCap: number,
  lendingBuffer: number,
  incentiveWeight: number,
  liquidationTokenPath?: string[]
};
const tokenParams: { [tokenName: string]: TokenInitRecord; } = {
  DAI: {
    exposureCap: 100000000,
    lendingBuffer: 10000,
    incentiveWeight: 5,
  },
  WETH: {
    exposureCap: 10000,
    lendingBuffer: 100,
    incentiveWeight: 5,
  },
  UNI: {
    exposureCap: 100000,
    lendingBuffer: 400,
    incentiveWeight: 5
  },
  MKR: {
    exposureCap: 500,
    lendingBuffer: 80,
    incentiveWeight: 5,
  },
  USDT: {
    exposureCap: 1000000,
    lendingBuffer: 10000,
    incentiveWeight: 5
  },
  LOCALPEG: {
    exposureCap: 1000000,
    lendingBuffer: 10000,
    incentiveWeight: 5
  }
};

function sortsBefore(a:string, b:string) {
  return a.toLowerCase() < b.toLowerCase();
}

function tokens2pair(tokenA:string, tokenB:string) {
  const tokens = sortsBefore(tokenA,  tokenB) ? [tokenA, tokenB] : [tokenB, tokenA];
  return getCreate2Address(
    UNI_FACTORY_ADDRESS,
    keccak256(['bytes'], [pack(['address', 'address'], tokens)]),
    UNI_INIT_CODE_HASH
  ).toString();
}

function path2pairs(tokenPath:string[]) {
  const adjacents = tokenPath.slice(1);
  return adjacents.map((nextToken, idx) => {
    return tokens2pair(nextToken, tokenPath[idx]);
  })
}

const deploy: DeployFunction = async function ({
  getNamedAccounts,
  deployments,
  getChainId,
  getUnnamedAccounts,
  network,
}: HardhatRuntimeEnvironment) {
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  const DC = await deployments.get("DependencyController");
  const dc = await ethers.getContractAt("DependencyController", DC.address);

  ethers.utils.parseUnits("10000", 18);

  const networkName = network.live ? network.name : 'local';
  const peg = network.live ? USDT_ADDRESS : (await deployments.get("Peg")).address;

  const tokens = network.live ? tokensPerNetwork[networkName] : {LOCALPEG: peg};

  const tokenAddresses = Object.values(tokens);
  const tokenNames = Object.keys(tokens);

  const exposureCaps = tokenNames.map((name) => {
    return ethers.utils.parseUnits(`${tokenParams[name].exposureCap}`, 18);
  });

  const lendingBuffers = tokenNames.map((name) => {
    return ethers.utils.parseUnits(`${tokenParams[name].lendingBuffer}`, 18);
  });
  const incentiveWeights = tokenNames.map((name) => tokenParams[name].incentiveWeight);


  const liquidationTokens = tokenNames.map((name) => {
    return tokens[name].liquidationTokenPath || [tokens[name], peg];
  });
  // TODO get the pairs from uni/sushi
  const liquidationPairs = liquidationTokens.map(path2pairs);


  const Roles = await deployments.get("Roles");
  const roles = await ethers.getContractAt("Roles", Roles.address);

  const args = [
    roles.address,
    tokenAddresses,
    exposureCaps,
    lendingBuffers,
    incentiveWeights,
    liquidationPairs,
    liquidationTokens
  ];

  console.log(args);

  const TokenActivation = await deploy("TokenActivation", {
    from: deployer,
    args,
    log: true,
    skipIfAlreadyDeployed: true,
  });

  if (TokenActivation.newlyDeployed) {
    console.log('Executing token activation');
    const tx = await dc.executeAsOwner(TokenActivation.address);
    console.log(`executing ${TokenActivation.address} as owner, by ${dc.address}, tx: ${tx.hash}`);  
  }
};

deploy.tags = ["TokenActivation", "local"];
deploy.dependencies = ["DependencyController"];
export default deploy;
