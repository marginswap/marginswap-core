const V1 = artifacts.require("V1");
const WETH = "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2";
const MFI_ADDRESS = "0xAa4e3edb11AFa93c41db59842b29de64b72E355B";
const REAL_TREASURY = "0x16F3Fc1E4BA9d70f47387b902fa5d21020b5C6B5";
const UNISWAP_FACTORY = "0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f";
const SUSHISWAP_FACTORY = "0xC0AEe478e3658e2610c5F7A4A2E1777cE9e4f2Ac";
const USDC_ADDRESS = "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48";

module.exports = function (deployer, network, accounts) {
    let treasury = REAL_TREASURY;
    let feesPer10k = 10;
    console.log([treasury, WETH, feesPer10k, MFI_ADDRESS, UNISWAP_FACTORY, SUSHISWAP_FACTORY, USDC_ADDRESS]);
    deployer.deploy(V1,
                    treasury,
                    WETH,
                    feesPer10k,
                    MFI_ADDRESS,
                    UNISWAP_FACTORY,
                    SUSHISWAP_FACTORY,
                    USDC_ADDRESS).then(() => {
                        console.log(`V1 address: ${V1.address}`);
                    });
}
