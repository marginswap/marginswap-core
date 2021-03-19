import { expect, assert } from "chai";
import { ethers, deployments } from "hardhat";

const ADDRESS_ONE = "0x0000000000000000000000000000000000000001";
const USDT_ADDRESS = "0xdac17f958d2ee523a2206206994597c13d831ec7";

describe("HourlyBondSubscriptionLending.viewHourlyBondAmount", function () {
    beforeEach(async () => {
        await deployments.fixture();
    });
    it("Should return bond balance for valid token and holder", async function () {
        const lending = await deployments
            .get("Lending")
            .then(lending => ethers.getContractAt("Lending", lending.address));

        const tokenAdmin = await deployments
            .get("TokenAdmin")
            .then(ta => ethers.getContractAt("TokenAdmin", ta.address));

        const [_owner, addr1] = await ethers.getSigners();
        const tokenAddr = ADDRESS_ONE;
        await tokenAdmin.activateToken(tokenAddr, 100_000, 100_000, 3, [tokenAddr, USDT_ADDRESS]);
        await lending.connect(addr1).buyHourlyBondSubscription(tokenAddr, 1000);
        const balance = await lending.viewHourlyBondAmount(tokenAddr, addr1.address);
        expect(balance).to.equal(1000);
    });
});