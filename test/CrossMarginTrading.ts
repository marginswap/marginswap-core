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
});

describe("CrossMarginTrading.registerDeposit", function () {
  beforeEach(async () => {
    await deployments.fixture();
  });
  it("Should revert if cap would be exceeded", async () => {
    const roles = await deployments
      .get("Roles")
      .then((Roles) => ethers.getContractAt("Roles", Roles.address));
    const CrossMarginTradingTest = await ethers.getContractFactory("CrossMarginTradingTest");
    const crossMarginTradingTest = await CrossMarginTradingTest.deploy(roles.address);
    const { deployer } = await getNamedAccounts();

    await roles.giveRole(MARGIN_TRADER, deployer);
    crossMarginTradingTest.updateRoleCache(MARGIN_TRADER, deployer);

    // exceeding cap
    expect(crossMarginTradingTest.registerDeposit(ADDRESS_ONE, ADDRESS_ONE, 1000))
      .to.be.reverted;
  });

  it("Should accept deposits under cap", async () => {
    const roles = await deployments
      .get("Roles")
      .then((Roles) => ethers.getContractAt("Roles", Roles.address));
    const CrossMarginTradingTest = await ethers.getContractFactory("CrossMarginTradingTest");
    const crossMarginTradingTest = await CrossMarginTradingTest.deploy(roles.address);
    const { deployer } = await getNamedAccounts();

    roles.giveRole(TOKEN_ACTIVATOR, deployer);
    roles.giveRole(MARGIN_TRADER, deployer);
    crossMarginTradingTest.updateRoleCache(MARGIN_TRADER, deployer);
    crossMarginTradingTest.updateRoleCache(TOKEN_ACTIVATOR, deployer);
    crossMarginTradingTest.setTokenCap(ADDRESS_ONE, 100000000);


    let holdingAmountsBefore = await crossMarginTradingTest.getHoldingAmounts(
      ADDRESS_ONE
    );
    await crossMarginTradingTest.registerDeposit(ADDRESS_ONE, ADDRESS_ONE, 1000);
    let holdingAmountsAfter = await crossMarginTradingTest.getHoldingAmounts(
      ADDRESS_ONE
    );

    expect(holdingAmountsBefore).not.to.equal(holdingAmountsAfter);
  });

  it("Should accept withdrawals", async () => {
    const roles = await deployments
      .get("Roles")
      .then((Roles) => ethers.getContractAt("Roles", Roles.address));
    const { deployer } = await getNamedAccounts();
    const CrossMarginTradingTest = await ethers.getContractFactory("CrossMarginTradingTest");
    const crossMarginTradingTest = await CrossMarginTradingTest.deploy(roles.address);

    roles.giveRole(TOKEN_ACTIVATOR, deployer);
    roles.giveRole(MARGIN_TRADER, deployer);
    crossMarginTradingTest.updateRoleCache(TOKEN_ACTIVATOR, deployer);
    crossMarginTradingTest.updateRoleCache(MARGIN_TRADER, deployer);

    crossMarginTradingTest.setTokenCap(ADDRESS_ONE, 100000000);
    crossMarginTradingTest.setLeverage(3);
    await crossMarginTradingTest.registerDeposit(ADDRESS_ONE, ADDRESS_ONE, 1000);

    await increaseBlocks();

    await crossMarginTradingTest.registerWithdrawal(ADDRESS_ONE, ADDRESS_ONE, 1000);

    const holdingAmounts = await crossMarginTradingTest.getHoldingAmounts(ADDRESS_ONE);

    expect(holdingAmounts.holdingAmounts[0]).to.equal(0);

  });
});

async function increaseBlocks() {
  for (let i = 0; i < 24; i++) {
    const timestamp =
      Math.floor(new Date().getTime() / 1000) + 1000000 + i * 1000;
    await network.provider.send("evm_mine", [timestamp]);
  }
}