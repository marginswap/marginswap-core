import { expect, assert } from "chai";
import { ethers, deployments, getNamedAccounts, network } from "hardhat";

const ADDRESS_ONE = "0x0000000000000000000000000000000000000001";
const MARGIN_TRADER = 4;
const TOKEN_ACTIVATOR = 9;

describe("CrossMarginTrading.getHoldingAmount", function () {
  beforeEach(async () => {
    await deployments.fixture();
  });
  it("Should return empty for non-existent account", async function () {
    const CrossMarginTrading = await deployments.get("CrossMarginTrading");
    const marginTradingContract = await ethers.getContractAt(
      "CrossMarginTrading",
      CrossMarginTrading.address
    );
    const holdingAmounts = await marginTradingContract.getHoldingAmounts(
      ADDRESS_ONE
    );

    expect(holdingAmounts).to.be.a("array");
    expect(holdingAmounts).to.have.lengthOf(2);
    expect(holdingAmounts).to.have.property("holdingAmounts").with.lengthOf(0);
    expect(holdingAmounts).to.have.property("holdingTokens").with.lengthOf(0);
  });

  it("Should handle deposits", async () => {
    const CrossMarginTrading = await deployments.get("CrossMarginTrading");
    const crossMarginTrading = await ethers.getContractAt(
      "CrossMarginTrading",
      CrossMarginTrading.address
    );

    const { deployer } = await getNamedAccounts();

    const roles = await deployments
      .get("Roles")
      .then((Roles) => ethers.getContractAt("Roles", Roles.address));

    await roles.giveRole(MARGIN_TRADER, deployer);
    crossMarginTrading.updateRoleCache(MARGIN_TRADER, deployer);

    // exceeding cap
    expect(crossMarginTrading.registerDeposit(ADDRESS_ONE, ADDRESS_ONE, 1000))
      .to.be.reverted;

    roles.giveRole(TOKEN_ACTIVATOR, deployer);
    crossMarginTrading.updateRoleCache(TOKEN_ACTIVATOR, deployer);
    crossMarginTrading.setTokenCap(ADDRESS_ONE, 100000000);

    await crossMarginTrading.registerDeposit(ADDRESS_ONE, ADDRESS_ONE, 1000);

    let holdingAmounts = await crossMarginTrading.getHoldingAmounts(
      ADDRESS_ONE
    );

    expect(holdingAmounts.holdingAmounts[0]).to.equal(1000);
    expect(holdingAmounts.holdingTokens[0]).to.equal(ADDRESS_ONE);
  });
});

async function increaseBlocks() {
  for (let i = 0; i < 24; i++) {
    const timestamp =
      Math.floor(new Date().getTime() / 1000) + 1000000 + i * 1000;
    await network.provider.send("evm_mine", [timestamp]);
  }
}

// await crossMarginTrading.registerWithdrawal(ADDRESS_ONE, ADDRESS_ONE, 1000);

// const holdingAmounts = await crossMarginTrading.getHoldingAmounts(ADDRESS_ONE);

// expect(holdingAmounts.holdingAmounts[0]).to.equal(0);
