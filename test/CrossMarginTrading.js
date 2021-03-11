const { expect, assert } = require("chai");
const { ethers, deployments } = require('hardhat');

const ADDRESS_ONE = '0x0000000000000000000000000000000000000001'

describe("CrossMarginTrading.getHoldingAmount", function () {
    beforeEach(async () => {
        await deployments.fixture();
    });
    it("Should return empty for non-existent account", async function () {
        const roles = await deployments.get("Roles");
        const marginTradingContract = await ethers.getContract("CrossMarginTrading", roles.address)
        const holdingAmounts = await marginTradingContract.getHoldingAmounts(ADDRESS_ONE);

        expect(holdingAmounts).to.be.a('array');
        expect(holdingAmounts).to.have.lengthOf(2);
        expect(holdingAmounts).to.have.property('holdingAmounts').with.lengthOf(0);
        expect(holdingAmounts).to.have.property('holdingTokens').with.lengthOf(0);
    });
});