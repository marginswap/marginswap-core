const { expect, assert } = require("chai");
const { ethers, deployments } = require('hardhat');
import ERC20PresetMinterPauser from "@openzeppelin/contracts/build/contracts/ERC20PresetMinterPauser.json";

const ADDRESS_ONE = '0x0000000000000000000000000000000000000001'

describe("Funds.activateToken", function () {
    beforeEach(async () => {
        await deployments.fixture();
    });
    it("", async function () {
        // const Token = await ethers.getContractFactory(ERC20PresetMinterPauser.abi);
        // const token = await Token.deploy();
    });
});