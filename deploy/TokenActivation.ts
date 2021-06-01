import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { DeployFunction } from 'hardhat-deploy/types';
import { ethers, hardhatArguments } from 'hardhat';
import { DeploymentsExtension } from 'hardhat-deploy/dist/types';
import { BigNumber } from '@ethersproject/bignumber';

// import ERC20PresetMinterPauser from '@openzeppelin/contracts/build/contracts/ERC20PresetMinterPauser.json';

const MFI_ADDRESS = '0xAa4e3edb11AFa93c41db59842b29de64b72E355B';
const TOKEN_ACTIVATOR = 9;

const UNI_FACTORY_ADDRESS = '0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f';

const UNI_INIT_CODE_HASH = '0x96e8ac4277198ff8b6f785478aa9a39f403cb768dd02cbee326c3e7da348845f';

const baseCurrency = {
  kovan: 'WETH',
  mainnet: 'WETH',
  avalanche: 'WAVAX',
  local: 'WETH'
};

export const tokensPerNetwork: Record<string, Record<string, string>> = {
  kovan: {
    //    USDT: USDT_ADDRESS,
    DAI: '0x4f96fe3b7a6cf9725f59d353f723c1bdb64ca6aa',
    WETH: '0xd0a1e359811322d97991e03f863a0c30c2cf029c',
    UNI: '0x1f9840a85d5af5bf1d1762f925bdaddc4201f984'
    //    MKR: "0xac94ea989f6955c67200dd67f0101e1865a560ea",
  },
  mainnet: {
    DAI: '0x6b175474e89094c44da98b954eedeac495271d0f',
    WETH: '0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2',
    UNI: '0x1f9840a85d5af5bf1d1762f925bdaddc4201f984',
    MKR: '0x9f8f72aa9304c8b593d555f12ef6589cc3a579a2',
    USDT: '0xdAC17F958D2ee523a2206206994597C13D831ec7',
    BOND: '0x0391D2021f89DC339F60Fff84546EA23E337750f',
    LINK: '0x514910771af9ca656af840dff83e8264ecf986ca',
    USDC: '0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48',
    WBTC: '0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599',
    SUSHI: '0x6b3595068778dd592e39a122f4f5a5cf09c90fe2',
    ALCX: '0xdbdb4d16eda451d0503b854cf79d55697f90c8df'
  },
  localhost: {
    DAI: '0x6b175474e89094c44da98b954eedeac495271d0f',
    WETH: '0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2',
    USDT: '0xdAC17F958D2ee523a2206206994597C13D831ec7',
    ALCX: '0xdbdb4d16eda451d0503b854cf79d55697f90c8df',
    UNI: '0x1f9840a85d5af5bf1d1762f925bdaddc4201f984'
  },
  avalanche: {
    WAVAX: '0xB31f66AA3C1e785363F0875A1B74E27b85FD66c7',
    ETH: '0xf20d962a6c8f70c731bd838a3a388D7d48fA6e15',
    PNG: '0x60781C2586D68229fde47564546784ab3fACA982',
    WBTC: '0x408D4cD0ADb7ceBd1F1A1C33A0Ba2098E1295bAB',
    USDT: '0xde3A24028580884448a5397872046a019649b084'
  }
};

export enum AMMs {
  UNISWAP,
  SUSHISWAP
}

export type TokenInitRecord = {
  exposureCap: number;
  lendingBuffer: number;
  incentiveWeight: number;
  liquidationTokenPath?: string[];
  decimals: number;
  ammPath?: AMMs[];
};
export const tokenParams: { [tokenName: string]: TokenInitRecord } = {
  DAI: {
    exposureCap: 10000000,
    lendingBuffer: 10000,
    incentiveWeight: 3,
    liquidationTokenPath: ['DAI', 'BASE'],
    decimals: 18
  },
  WETH: {
    exposureCap: 100000,
    lendingBuffer: 500,
    incentiveWeight: 3,
    liquidationTokenPath: ['BASE'],
    decimals: 18
  },
  UNI: {
    exposureCap: 100000,
    lendingBuffer: 500,
    incentiveWeight: 5,
    liquidationTokenPath: ['UNI', 'BASE'],
    decimals: 18
  },
  MKR: {
    exposureCap: 2000,
    lendingBuffer: 80,
    incentiveWeight: 5,
    liquidationTokenPath: ['MKR', 'BASE'],
    decimals: 18
  },
  USDT: {
    exposureCap: 100000000,
    lendingBuffer: 10000,
    incentiveWeight: 3,
    liquidationTokenPath: ['USDT', 'BASE'],
    decimals: 6
  },
  BOND: {
    exposureCap: 50000,
    lendingBuffer: 100,
    incentiveWeight: 1,
    liquidationTokenPath: ['BOND', 'USDC'],
    decimals: 18
  },
  LINK: {
    exposureCap: 200000,
    lendingBuffer: 100,
    incentiveWeight: 1,
    liquidationTokenPath: ['LINK', 'BASE'],
    decimals: 18,
    ammPath: [AMMs.SUSHISWAP, AMMs.UNISWAP]
  },
  USDC: {
    exposureCap: 100000000,
    lendingBuffer: 10000,
    incentiveWeight: 3,
    liquidationTokenPath: ['USDC', 'BASE'],
    decimals: 6
  },
  WBTC: {
    exposureCap: 2000,
    lendingBuffer: 20,
    incentiveWeight: 3,
    liquidationTokenPath: ['WBTC', 'BASE'],
    decimals: 8
  },
  SUSHI: {
    exposureCap: 300000,
    lendingBuffer: 4000,
    incentiveWeight: 1,
    liquidationTokenPath: ['SUSHI', 'BASE'],
    decimals: 18,
    ammPath: [AMMs.SUSHISWAP, AMMs.SUSHISWAP, AMMs.SUSHISWAP]
  },
  ALCX: {
    exposureCap: 10000,
    lendingBuffer: 100,
    incentiveWeight: 2,
    liquidationTokenPath: ['ALCX', 'BASE'],
    decimals: 18,
    ammPath: [AMMs.SUSHISWAP, AMMs.SUSHISWAP, AMMs.SUSHISWAP]
  },
  WAVAX: {
    exposureCap: 1000000,
    lendingBuffer: 10000,
    incentiveWeight: 3,
    liquidationTokenPath: ['WAVAX'],
    decimals: 18
  },
  ETH: {
    exposureCap: 100000,
    lendingBuffer: 500,
    incentiveWeight: 3,
    liquidationTokenPath: ['ETH', 'BASE'],
    decimals: 18
  },
  PNG: {
    exposureCap: 1000000,
    lendingBuffer: 1,
    incentiveWeight: 3,
    liquidationTokenPath: ['PNG', 'BASE'],
    decimals: 18
  },

  LOCALPEG: {
    exposureCap: 1000000,
    lendingBuffer: 10000,
    incentiveWeight: 5,
    decimals: 18
  }
};

export function encodeAMMPath(ammPath: AMMs[]) {
  const encoded = ethers.utils.hexlify(ammPath.map((amm: AMMs) => (amm == AMMs.UNISWAP ? 0 : 1)));
  return `${encoded}${'0'.repeat(64 + 2 - encoded.length)}`;
}

const deploy: DeployFunction = async function ({
  getNamedAccounts,
  deployments,
  getChainId,
  getUnnamedAccounts,
  network
}: HardhatRuntimeEnvironment) {
  const { deploy } = deployments;
  const { deployer, baseCurrency } = await getNamedAccounts();

  const DC = await deployments.get('DependencyController');
  const dc = await ethers.getContractAt('DependencyController', DC.address);

  const networkName = network.name;
  console.log(`networkName: ${networkName}`);
  const peg = (await deployments.get('Peg')).address;

  const tokens = tokensPerNetwork[networkName];
  const tokenNames = Object.keys(tokens);
  const tokenAddresses = Object.values(tokens);

  const argLists = [
    await prepArgs(tokenNames.slice(0, 5), tokenAddresses.slice(0, 5), deployments, tokens, peg, baseCurrency)
    // await prepArgs(tokenNames.slice(5, 8), tokenAddresses.slice(5, 8), deployments, tokens, peg, baseCurrency),
    //await prepArgs(tokenNames.slice(8), tokenAddresses.slice(8), deployments, tokens, peg, baseCurrency)
  ];

  // await byHand(deployments, ...argLists[0]);

  for (const args of argLists) {
    const TokenActivation = await deploy('TokenActivation', {
      from: deployer,
      args,
      log: true,
      skipIfAlreadyDeployed: true
    });

    // run if it hasn't self-destructed yet
    if ((await ethers.provider.getCode(TokenActivation.address)) !== '0x') {
      console.log(`Executing token activation ${TokenActivation.address} via dependency controller ${dc.address}`);
      const tx = await dc.executeAsOwner(TokenActivation.address, { gasLimit: 5000000 });
      console.log(`ran ${TokenActivation.address} as owner, tx: ${tx.hash}`);
    }
  }

  // const TREASURY = '0xB3f923eaBAF178fC1BD8E13902FC5C61D3DdEF5B';
  // const TREASURY = '0xF9D89Dc506c55738379C44Dc27205fD6f68e1974';
  const TREASURY = '0x16F3Fc1E4BA9d70f47387b902fa5d21020b5C6B5';
  // if we are impersonating, steal some crypto
  if (!network.live) {
    await network.provider.request({
      method: 'hardhat_impersonateAccount',
      params: [TREASURY]
    });

    const signer = await ethers.provider.getSigner(TREASURY);
    // let tx = await signer.sendTransaction({ to: deployer, value: ethers.utils.parseEther('10') });
    // console.log(`Sending eth from treasury to ${deployer}:`);

    // const dai = await ethers.getContractAt(ERC20PresetMinterPauser.abi, tokens['DAI']);
    // const tx = await dai.connect(signer).transfer(deployer, ethers.utils.parseEther('200'));
    // console.log(`Sending dai from treasury to ${deployer}:`);

    // // const usdt = await ethers.getContractAt(ERC20PresetMinterPauser.abi, tokens['USDT']);
    // tx = await usdt.connect(signer).transfer(deployer, ethers.utils.parseEther('50'));
    // console.log(`Sending usdt from treasury to ${deployer}:`);
    // console.log(tx);

    // const problem = "0x07c2af75788814BA7e5225b2F5c951eD161cB589";
    // await network.provider.request({
    //   method: 'hardhat_impersonateAccount',
    //   params: [problem]
    // });

    // signer = await ethers.provider.getSigner(problem);
    // const router = await (await ethers.getContractAt('MarginRouter', "0xb80d5989F2ecB199603740197Ce9223b239547E0")).connect(signer);
    // let tx = await router.crossDeposit('0x6b3595068778dd592e39a122f4f5a5cf09c90fe2', ethers.utils.parseEther('186'));
    // console.log(tx);
  }

  // WAVAX: '0xB31f66AA3C1e785363F0875A1B74E27b85FD66c7',
  // ETH: '0xf20d962a6c8f70c731bd838a3a388D7d48fA6e15',
  // PNG: '0x60781C2586D68229fde47564546784ab3fACA982',
  // WBTC: '0x408D4cD0ADb7ceBd1F1A1C33A0Ba2098E1295bAB',
  // USDT: '0xde3A24028580884448a5397872046a019649b084'

  // const addresses = {
  //   "Admin": "0xBc4f35f44fFC68786B485Bd60a4B40cF4d3C3E03",
  //   "CrossMarginTrading": "0x64184c48f2cD779DAb3167a0f6AC10ab258f6ca3",
  //   "DependencyController": "0x4F080c404ac75986c95959a3AEc98Ac32403770D",
  //   "Fund": "0x669EA215966e75f0db563dE2298d0CED65ED5d3F",
  //   "Lending": "0xe6fe59966cBaf23726cb6513d410877FEC9ca4CF",
  //   "LiquidityMiningReward": "0x237B0b367d919Cafa95F9cdcce79D7DE0Bd98E6e",
  //   "MFIStaking": "0x167db869D99A717E14518B94d252fdC6DEaaCdF1",
  //   "MarginRouter": "0xc4d34d713a41017f523F3b74b801c7D5B9955c16",
  //   "Peg": "0xde3A24028580884448a5397872046a019649b084",
  //   "Roles": "0xb8a63dBb2C5B775067444EaEF60722806524F7FD",
  //   "SpotRouter": "0x9d2abbaFDFC8D851669dF5D671Bc967427897223",
  //   "TokenActivation": "0xDfA2df4f6f6A402931000A3823fccF9b926FDB3E"
  // };
  // const router = await ethers.getContractAt('SpotRouter', addresses['SpotRouter']);
  // const currentTime = Math.floor(Date.now() / 1000);
  // let tx = await router.swapExactETHForTokens(
  //   10000000,
  //   encodeAMMPath([AMMs.UNISWAP]),
  //   ['0xB31f66AA3C1e785363F0875A1B74E27b85FD66c7',  '0x60781C2586D68229fde47564546784ab3fACA982'],
  //   deployer,
  //   currentTime + 60 * 60,
  //   {value: `10${'0'.repeat(18)}`}
  // );
  // console.log(`sending png: ${tx.hash}`);

  // const fund = addresses['Fund'];
  // tx = await (await ethers.getContractAt(ERC20PresetMinterPauser.abi, '0x60781C2586D68229fde47564546784ab3fACA982')).approve(fund, `10000${'0'.repeat(18)}`);
  // console.log(`approve PNG: ${tx.hash}`);

  // const lending = await ethers.getContractAt('Lending', addresses['Lending']);
  // tx = await lending.buyHourlyBondSubscription('0x60781C2586D68229fde47564546784ab3fACA982', `10${'0'.repeat(18)}`);
  // console.log(`hourly bond subscription: ${tx.hash}`);
};

deploy.tags = ['TokenActivation', 'local'];
deploy.dependencies = ['DependencyController'];
export default deploy;

async function prepArgs(
  tokenNames: string[],
  tokenAddresses: string[],
  deployments,
  tokens,
  peg,
  baseCurrency
): Promise<[string, string[], BigNumber[], string[], any[][]]> {
  const exposureCaps = tokenNames.map(name => {
    return ethers.utils.parseUnits(`${tokenParams[name].exposureCap}`, tokenParams[name].decimals);
  });

  const liquidationTokens = tokenNames.map(name => {
    const tokenPath = tokenParams[name].liquidationTokenPath;
    return tokenPath
      ? [...tokenPath.map(tName => (tName == 'BASE' ? baseCurrency : tokens[tName])), peg]
      : [tokens[name], baseCurrency, peg];
  });

  const liquidationAmms = tokenNames.map(name =>
    tokenParams[name].ammPath ? encodeAMMPath(tokenParams[name].ammPath) : ethers.utils.hexZeroPad('0x00', 32)
  );

  const Roles = await deployments.get('Roles');
  const roles = await ethers.getContractAt('Roles', Roles.address);

  const args: [string, string[], BigNumber[], string[], any[][]] = [
    roles.address,
    tokenAddresses,
    exposureCaps,
    //lendingBuffers,
    //incentiveWeights,
    liquidationAmms,
    liquidationTokens
  ];
  return args;
}

async function byHand(
  deployments: DeploymentsExtension,
  _: string,
  tokens: string[],
  exposureCaps: BigNumber[],
  liquidationAmms: string[],
  liquidationTokens: string[][]
) {
  const Lending = await ethers.getContractAt('Lending', (await deployments.get('Lending')).address);
  const cmt = await ethers.getContractAt('CrossMarginTrading', (await deployments.get('CrossMarginTrading')).address);

  for (let i = 0; tokens.length > i; i++) {
    const token = tokens[i];
    const exposureCap = exposureCaps[i];
    const ammPath = liquidationAmms[i];
    const liquidationTokenPath = liquidationTokens[i];

    let tx = await Lending['activateIssuer(address)'](token);
    console.log(`activateIssuer for ${token}: ${tx.hash}`);

    // tx = await cmt.setTokenCap(token, exposureCap);
    // console.log(`setTokenCap for ${token}: ${tx.hash}`);

    tx = await Lending.setLendingCap(token, exposureCap, { gasLimit: 500000 });
    console.log(`setLendingCap for ${token}: ${tx.hash}`);

    tx = await Lending.setHourlyYieldAPR(token, '0');
    console.log(`Init hourly yield apr for ${token}: ${tx.hash}`);

    tx = await Lending.initBorrowYieldAccumulator(token, { gasLimit: 5000000 });
    console.log(`initBorrowYieldAccu for ${token}: ${tx.hash}`);

    // const tx = await cmt.setLiquidationPath(ammPath, liquidationTokenPath, { gasLimit: 5000000 });
    // console.log(`setLiquidationPath for ${token}: ${tx.hash}`);
  }
}
