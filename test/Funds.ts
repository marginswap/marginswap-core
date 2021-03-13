const { expect, assert } = require("chai");
const { ethers, deployments, getNamedAccounts } = require('hardhat');
import ERC20PresetMinterPauser from "@openzeppelin/contracts/build/contracts/ERC20PresetMinterPauser.json";

const ADDRESS_ONE = '0x0000000000000000000000000000000000000001'

describe("Funds.activateToken", function () {
    beforeEach(async () => {
        await deployments.fixture();
    });
    it("should allow a valid activator to activate a token", async function () {
        const Token = await ethers.getContractFactory(ERC20PresetMinterPauser.abi, ERC20PresetMinterPauser.bytecode);
        const token = await Token.deploy("MFITestToken", "MFITT");
        await token.deployed();

        const Fund = await deployments.get("Fund");
        const fund = await ethers.getContract("Fund", Fund.address);

        const [owner] = await ethers.getSigners();

        console.log(owner.address);
        await fund.connect(owner.address).activateToken(token.address);
    });
});