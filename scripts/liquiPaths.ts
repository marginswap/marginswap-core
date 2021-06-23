import addresses from '../build/addresses.json';
import { tokensPerNetwork } from '../deploy/TokenActivation'
import { getCreate2Address } from '@ethersproject/address';
import { pack, keccak256 } from '@ethersproject/solidity'


const UNI_FACTORY_ADDRESS = '0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f'

const UNI_INIT_CODE_HASH = '0x96e8ac4277198ff8b6f785478aa9a39f403cb768dd02cbee326c3e7da348845f'

export enum AMMs {
    UNI,
    SUSHI
}

export const factoryAddresses: Record<AMMs, string> = {
    [AMMs.UNI]: '0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f',
    [AMMs.SUSHI]: '0xC0AEe478e3658e2610c5F7A4A2E1777cE9e4f2Ac'
};
  
export const amms: Record<string, AMMs> = {
    [factoryAddresses[AMMs.UNI]]: AMMs.UNI,
    [factoryAddresses[AMMs.SUSHI]]: AMMs.SUSHI
};
  
export const initCodeHashes: Record<string, string> = {
    [factoryAddresses[AMMs.UNI]]: '0x96e8ac4277198ff8b6f785478aa9a39f403cb768dd02cbee326c3e7da348845f',
    [factoryAddresses[AMMs.SUSHI]]: '0xe18a34eb0e04b04f7a0ac29a6e80748dca96319b42c54d679cb821dca90c6303'
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
  

export async function inspectLiqui(hre:any) {
    const mainAdrs = addresses[1];

    const crossMargin = await hre.ethers.getContractAt('CrossMarginTrading', mainAdrs.CrossMarginTrading);

    for (const [name, address] of Object(tokensPerNetwork.mainnet)) {
        const tP = await crossMargin.tokenPrices(address);

        console.log(`Token price for ${name}:`);
        console.log(tP);
    }
}
