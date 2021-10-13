import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { DeployFunction } from 'hardhat-deploy/types';
import { ethers, hardhatArguments } from 'hardhat';
import { DeploymentsExtension } from 'hardhat-deploy/dist/types';
import { BigNumber } from '@ethersproject/bignumber';

const MFI_ADDRESS = '0xAa4e3edb11AFa93c41db59842b29de64b72E355B';
const TOKEN_ACTIVATOR = 9;

const UNI_FACTORY_ADDRESS = '0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f';

const UNI_INIT_CODE_HASH = '0x96e8ac4277198ff8b6f785478aa9a39f403cb768dd02cbee326c3e7da348845f';

const baseCurrency = {
  kovan: 'WETH',
  mainnet: 'WETH',
  avalanche: 'WAVAX',
  localhost: 'WETH',
  matic: 'WETH',
  bsc: 'WBNB'
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
    ALCX: '0xdbdb4d16eda451d0503b854cf79d55697f90c8df',
    YFI: '0x0bc529c00C6401aEF6D220BE8C6Ea1667F6Ad93e',
    FRAX: '0x853d955acef822db058eb8505911ed77f175b99e'
  },
  localhost: {
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
    ALCX: '0xdbdb4d16eda451d0503b854cf79d55697f90c8df',
    YFI: '0x0bc529c00C6401aEF6D220BE8C6Ea1667F6Ad93e',
    FRAX: '0x853d955acef822db058eb8505911ed77f175b99e'
  },
  avalanche: {
    WAVAX: '0xB31f66AA3C1e785363F0875A1B74E27b85FD66c7',
    ETH: '0x49D5c2BdFfac6CE2BFdB6640F4F80f226bc10bAB',
    PNG: '0x60781C2586D68229fde47564546784ab3fACA982',
//    WBTC: '0x408D4cD0ADb7ceBd1F1A1C33A0Ba2098E1295bAB',
    USDT: '0xc7198437980c041c805A1EDcbA50c1Ce5db95118',
    YAK: '0x59414b3089ce2AF0010e7523Dea7E2b35d776ec7',
    QI: '0x8729438EB15e2C8B576fCc6AeCdA6A148776C0F5',
    XAVA: '0xd1c3f94DE7e5B45fa4eDBBA472491a9f4B166FC4'
  },
  matic: {
    USDC: "0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174",
    WBTC: "0x1BFD67037B42Cf73acF2047067bd4F2C47D9BfD6",
    DAI: "0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063",
    WETH: "0x7ceB23fD6bC0adD59E62ac25578270cFf1b9f619",
    WMATIC: "0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270",
    USDT: "0xc2132D05D31c914a87C6611C10748AEb04B58e8F",
    LINK: "0x53E0bca35eC356BD5ddDFebbD1Fc0fD03FaBad39",
    AAVE: "0xD6DF932A45C0f255f85145f286eA0b292B21C90B",
    QUICK: "0x831753dd7087cac61ab5644b308642cc1c33dc13",
    MAI: "0xa3fa99a148fa48d14ed51d610c367c61876997f1"
  },
  bsc: {
    WBNB: '0xbb4cdb9cbd36b01bd1cbaebf2de08d9173bc095c',
    CAKE: '0x0e09fabb73bd3ade0a17ecc321fd13a19e81ce82',
    ETH: '0x2170ed0880ac9a755fd29b2688956bd959f933f8',
    USDC: '0x8ac76a51cc950d9822d68b83fe1ad97b32cd580d',
    BUSD: '0xe9e7cea3dedca5984780bafc599bd69add087d56',
    DAI: '0x1af3f329e8be154074d8769d1ffa4ee058b1dbc3',
    BTCB: '0x7130d2a12b9bcbfae4f2634d864a1ee1ce3ead9c',
    USDT: '0x55d398326f99059ff775485246999027b3197955'
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
  oracleContract?: string;
};
export const tokenParams: { [tokenName: string]: TokenInitRecord } = {
  XAVA: {
    exposureCap: 200000,
    lendingBuffer: 100,
    incentiveWeight: 1,
    liquidationTokenPath: ['XAVA', 'BASE'],
    decimals: 18,
    ammPath: [AMMs.UNISWAP, AMMs.UNISWAP]
  },
  QI: {
    exposureCap: 200000,
    lendingBuffer: 100,
    incentiveWeight: 1,
    liquidationTokenPath: ['QI', 'BASE'],
    decimals: 18,
    ammPath: [AMMs.UNISWAP, AMMs.UNISWAP]
  },
  YAK: {
    exposureCap: 200000,
    lendingBuffer: 100,
    incentiveWeight: 1,
    liquidationTokenPath: ['YAK', 'BASE'],
    decimals: 18,
    ammPath: [AMMs.UNISWAP, AMMs.UNISWAP]
  },
  USDTe: {
    exposureCap: 100000000,
    lendingBuffer: 10000,
    incentiveWeight: 3,
    liquidationTokenPath: ['USDTe', 'BASE'],
    decimals: 6
  },
  FRAX: {
    exposureCap: 10000000,
    lendingBuffer: 10000,
    incentiveWeight: 3,
    liquidationTokenPath: ['FRAX', 'BASE'],
    decimals: 18
  },
  YFI: {
    exposureCap: 200,
    lendingBuffer: 20,
    incentiveWeight: 3,
    liquidationTokenPath: ['YFI', 'BASE'],
    decimals: 18
  },
  WBNB: {
    exposureCap: 1000000,
    lendingBuffer: 10000,
    incentiveWeight: 3,
    liquidationTokenPath: ['WBNB'],
    decimals: 18
  },
  CAKE: {
    exposureCap: 200000,
    lendingBuffer: 100,
    incentiveWeight: 1,
    liquidationTokenPath: ['CAKE', 'BASE'],
    decimals: 18,
    ammPath: [AMMs.UNISWAP, AMMs.UNISWAP]
  },
  BUSD: {
    exposureCap: 10000000,
    lendingBuffer: 10000,
    incentiveWeight: 3,
    liquidationTokenPath: ['BUSD', 'BASE'],
    decimals: 18
  },
  BTCB: {
    exposureCap: 2000,
    lendingBuffer: 20,
    incentiveWeight: 3,
    liquidationTokenPath: ['BTCB', 'BASE'],
    decimals: 18
  },
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
    ammPath: [AMMs.UNISWAP, AMMs.UNISWAP]
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
  WMATIC: {
    exposureCap: 1000000,
    lendingBuffer: 10000,
    incentiveWeight: 3,
    liquidationTokenPath: ['WMATIC'],
    decimals: 18
  },
  ETH: {
    exposureCap: 100000,
    lendingBuffer: 500,
    incentiveWeight: 3,
    liquidationTokenPath: ['ETH', 'BASE'],
    decimals: 18
  },
  WETHe: {
    exposureCap: 100000,
    lendingBuffer: 500,
    incentiveWeight: 3,
    liquidationTokenPath: ['WETHe', 'BASE'],
    decimals: 18
  },
  PNG: {
    exposureCap: 1000000,
    lendingBuffer: 1,
    incentiveWeight: 3,
    liquidationTokenPath: ['PNG', 'BASE'],
    decimals: 18
  },
  QUICK: {
    exposureCap: 1000000,
    lendingBuffer: 1,
    incentiveWeight: 3,
    liquidationTokenPath: ['QUICK', 'BASE'],
    decimals: 18
  },
  MAI: {
    exposureCap: 1000000,
    lendingBuffer: 1,
    incentiveWeight: 3,
    liquidationTokenPath: ['MAI', 'BASE'],
    decimals: 18
  },
  AAVE: {
    exposureCap: 1000000,
    lendingBuffer: 1,
    incentiveWeight: 3,
    liquidationTokenPath: ['AAVE', 'BASE'],
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
  const { deployer } = await getNamedAccounts();

  const DC = await deployments.get('DependencyController');
  const dc = await ethers.getContractAt('DependencyController', DC.address);

  const networkName = network.name;
  console.log(`networkName: ${networkName}`);
  const peg = (await deployments.get('Peg')).address;

  const tokens = tokensPerNetwork[networkName];
  const tokenNames = Object.keys(tokens);
  const tokenAddresses = Object.values(tokens);

  // const argLists = [
  //   await prepArgs(['XAVA'], [tokens['XAVA']], deployments, tokens, peg, baseCurrency[networkName])
  // ];

  const argLists = [
    await prepArgs(tokenNames.slice(0, 5), tokenAddresses.slice(0, 5), deployments, tokens, peg, baseCurrency[networkName])
  ];

  if (tokenNames.length > 5) {
    argLists.push(
      await prepArgs(tokenNames.slice(5, 8), tokenAddresses.slice(5, 8), deployments, tokens, peg, baseCurrency[networkName])
    );
    if (tokenNames.length > 8) {
      argLists.push(
        await prepArgs(tokenNames.slice(8), tokenAddresses.slice(8), deployments, tokens, peg, baseCurrency[networkName])
      );
    }
  }

  let skipIfAlreadyDeployed = true;
  for (const args of argLists) {

    const TokenActivation = await deploy('TokenActivation', {
      from: deployer,
      args,
      log: true,
      skipIfAlreadyDeployed
    });

    if (TokenActivation.newlyDeployed) {
      // we are deploying a new raft of token activations
      skipIfAlreadyDeployed = false;
    }

    // run if it hasn't self-destructed yet
    if ((await ethers.provider.getCode(TokenActivation.address)) !== '0x') {
      console.log(`Executing token activation ${TokenActivation.address} via dependency controller ${dc.address}`);
      const tx = await dc.executeAsOwner(TokenActivation.address, { gasLimit: 8000000 });
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
deploy.dependencies = ['DependencyController', 'TwapOracle', 'SnowglobeOracle'];
export default deploy;

async function prepArgs(
  tokenNames: string[],
  tokenAddresses: string[],
  deployments,
  tokens,
  peg,
  baseCurrencyName
): Promise<[string, string[], BigNumber[], string[], any[][], string[]]> {
  const exposureCaps = tokenNames.map(name => {
    return ethers.utils.parseUnits(`${tokenParams[name].exposureCap}`, tokenParams[name].decimals);
  });

  const liquidationTokens = tokenNames.map(name => {
    const tokenPath = tokenParams[name].liquidationTokenPath;
    return tokenPath
      ? [...tokenPath.map(tName => (tName == 'BASE' ? tokens[baseCurrencyName] : tokens[tName])), peg]
      : [tokens[name], baseCurrency, peg];
  });

  const liquidationAmms = tokenNames.map(name =>
    tokenParams[name].ammPath ? encodeAMMPath(tokenParams[name].ammPath) : ethers.utils.hexZeroPad('0x00', 32)
  );

  const oracleAddresses = await Promise.all(tokenNames.map(async name => {
    return tokenParams[name].oracleContract ? (await deployments.get(tokenParams[name].oracleContract)).address : ethers.constants.AddressZero
  }));

  const Roles = await deployments.get('Roles');
  const roles = await ethers.getContractAt('Roles', Roles.address);

  const args: [string, string[], BigNumber[], string[], any[][], string[]] = [
    roles.address,
    tokenAddresses,
    exposureCaps,
    //lendingBuffers,
    //incentiveWeights,
    liquidationAmms,
    liquidationTokens,
    oracleAddresses
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
