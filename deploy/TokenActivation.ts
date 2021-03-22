import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { hrtime } from "node:process";
import { ethers } from "hardhat";

const USDT_ADDRESS = "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2";
const MFI_ADDRESS = "0xAa4e3edb11AFa93c41db59842b29de64b72E355B";
const TOKEN_ACTIVATOR = 9;

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
  liquidationPath?: string[];
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
  }
};

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
  const tokens = tokensPerNetwork[networkName];
  const tokenAddresses = Object.values(tokens);
  const tokenNames = Object.keys(tokens);
  const exposureCaps = tokenNames.map((name) => {
    return ethers.utils.parseUnits(`${tokenParams[name].exposureCap}`, 18);
  });
  const lendingBuffers = tokenNames.map((name) => {
    return ethers.utils.parseUnits(`${tokenParams[name].lendingBuffer}`, 18);
  });
  const incentiveWeights = tokenNames.map((name) => tokenParams[name].incentiveWeight);
  const liquidationPaths = tokenNames.map((name) => {
    return tokens[name].liquidationPath || [tokens[name], peg];
  });

  const TokenActivation = await deploy("TokenActivation", {
    from: deployer,
    args: [
      dc.address,
      tokenAddresses,
      exposureCaps,
      lendingBuffers,
      incentiveWeights,
      liquidationPaths
    ],
    log: true,
    skipIfAlreadyDeployed: true,
  });

  if (await ethers.getDefaultProvider().getCode(TokenActivation.address) != "0x") {
    // execute if the contract hasn't self-destroyed yet
    const tx = await dc.executeAsOwner(TokenActivation.address);
    console.log(`executing ${TokenActivation} as owner, by ${dc.address}, tx: ${tx.hash}`);  
  }
};

deploy.tags = ["TokenActivation", "local"];
deploy.dependencies = ["DependencyController"];
export default deploy;
