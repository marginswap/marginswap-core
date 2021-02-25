const { expect, assert } = require("chai");

describe("MarginTrading.getHoldingAmount", function () {
    it("Should return empty for non-existent account", async function () {
        const Roles = await ethers.getContractFactory("Roles");
        const roles = await Roles.deploy();
        await roles.deployed();

        const MarginTrading = await ethers.getContractFactory("MarginTrading");
        const marginTrading = await MarginTrading.deploy(roles.address);
        await marginTrading.deployed();

        const holdingAmounts = await marginTrading.getHoldingAmounts(roles.address);

        expect(holdingAmounts).to.be.a('array');
        expect(holdingAmounts).to.have.lengthOf(2);
        expect(holdingAmounts).to.have.property('holdingAmounts').with.lengthOf(0);
        expect(holdingAmounts).to.have.property('holdingTokens').with.lengthOf(0);
    });
});