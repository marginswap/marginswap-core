const { expect } = require("chai");

describe("MarginTrading", function () {
    it("Should return empty for non-existent account", async function () {
        const Roles = await ethers.getContractFactory("Roles");
        const roles = await Roles.deploy();
        await roles.deployed();

        const MarginTrading = await ethers.getContractFactory("MarginTrading");
        const marginTrading = await MarginTrading.deploy(roles.address);
        await marginTrading.deployed();

        expect(await marginTrading.getHoldingAmounts("nonexistentaddress")).to.equal("Hello, world!");
    });
});