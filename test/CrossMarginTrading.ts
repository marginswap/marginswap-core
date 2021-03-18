import { expect, assert } from "chai";
import { ethers, deployments, getNamedAccounts, network } from "hardhat";
import ERC20PresetMinterPauser from "@openzeppelin/contracts/build/contracts/ERC20PresetMinterPauser.json";

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

  it("Should return results for existent account", async function () {
    const crossMarginTrading = await getCrossMarginTradingContract();
    await makeDeposit(crossMarginTrading);

    let holdingAmounts = await crossMarginTrading.getHoldingAmounts(
      ADDRESS_ONE
    );

    expect(holdingAmounts).to.be.a("array");
    expect(holdingAmounts).to.have.lengthOf(2);
    expect(holdingAmounts).to.have.property("holdingAmounts").with.lengthOf(1);
    expect(holdingAmounts).to.have.property("holdingTokens").with.lengthOf(1);
    expect(holdingAmounts.holdingAmounts[0]).to.equal(1000);
    expect(holdingAmounts.holdingTokens[0]).to.equal(ADDRESS_ONE);
  });
});

describe("CrossMarginTrading.registerDeposit", function () {
  beforeEach(async () => {
    await deployments.fixture();
  });
  it("Should revert if cap would be exceeded", async () => {
    const crossMarginTrading = await getCrossMarginTradingContract();

    // exceeding cap
    expect(crossMarginTrading.registerDeposit(ADDRESS_ONE, ADDRESS_ONE, 1000))
      .to.be.reverted;
  });

  it("Should accept deposits under cap", async () => {
    const crossMarginTrading = await getCrossMarginTradingContract();

    let holdingAmountsBefore = await crossMarginTrading.getHoldingAmounts(
      ADDRESS_ONE
    );
    await crossMarginTrading.registerDeposit(ADDRESS_ONE, ADDRESS_ONE, 1000);
    let holdingAmountsAfter = await crossMarginTrading.getHoldingAmounts(
      ADDRESS_ONE
    );

    expect(holdingAmountsBefore).not.to.equal(holdingAmountsAfter);
  });
});

// describe("CrossMarginTrading.registerWithdrawal", function () {
//   beforeEach(async () => {
//     await deployments.fixture();
//   });
//   it("Should accept withdrawals", async () => {
//     const crossMarginTrading = await getCrossMarginTradingContract();
//     crossMarginTrading.setLeverage(3);
//     await crossMarginTrading.registerDeposit(ADDRESS_ONE, ADDRESS_ONE, 1000);
//     await increaseBlocks();
//     await crossMarginTrading.registerWithdrawal(ADDRESS_ONE, ADDRESS_ONE, 1000);
// const holdingAmounts = await crossMarginTrading.getHoldingAmounts(ADDRESS_ONE);
// expect(holdingAmounts.holdingAmounts[0]).to.equal(0);
//   });
// });

// describe("CrossMarginTrading.registerBorrows", function () {
//   beforeEach(async () => {
//     await deployments.fixture();
//   });
//   it("Should allow borrows", async () => {
//     const token = await makeTestToken();
//     const crossMarginTrading = await getCrossMarginTradingContract();
//     crossMarginTrading.setTokenCap(token.address, 100000000);

//     const Lending = await deployments.get("Lending");
//     const lending = await ethers.getContractAt("Lending", Lending.address);
//     const TokenAdmin = await deployments.get("TokenAdmin");
//     const tokenAdmin = await ethers.getContractAt("TokenAdmin", TokenAdmin.address);

//     await tokenAdmin.activateToken(token.address, 10000000, 10000000, 30, [token.address, crossMarginTrading.peg()]);
// await crossMarginTrading.registerBorrow(ADDRESS_ONE, token.address, 1000);

// const [tokens, amounts] = await crossMarginTrading.getBorrowAmounts(ADDRESS_ONE);
// console.log(amounts);
//   });
// });

async function makeTestToken() {
  const Token = await ethers.getContractFactory(
    ERC20PresetMinterPauser.abi,
    ERC20PresetMinterPauser.bytecode
  );
  const token = await Token.deploy("MFITestToken", "MFITT");
  await token.deployed();
  return token;
}

async function getCrossMarginTradingContract() {
  const { deployer } = await getNamedAccounts();
  const roles = await deployments
    .get("Roles")
    .then((Roles) => ethers.getContractAt("Roles", Roles.address));
  const crossMarginTrading = await deployments
    .get("CrossMarginTrading")
    .then((cmt) => ethers.getContractAt("CrossMarginTrading", cmt.address));
  // const CrossMarginTradingTest = await ethers.getContractFactory("CrossMarginTradingTest");
  // const crossMarginTrading = await CrossMarginTradingTest.deploy(roles.address);
  roles.giveRole(TOKEN_ACTIVATOR, deployer);
  roles.giveRole(MARGIN_TRADER, deployer);
  crossMarginTrading.updateRoleCache(MARGIN_TRADER, deployer);
  crossMarginTrading.updateRoleCache(TOKEN_ACTIVATOR, deployer);
  crossMarginTrading.setTokenCap(ADDRESS_ONE, 100000000);
  return crossMarginTrading;
}

async function makeDeposit(crossMarginTrading) {
  return await crossMarginTrading.registerDeposit(ADDRESS_ONE, ADDRESS_ONE, 1000);
}

async function increaseBlocks() {
  for (let i = 0; i < 24; i++) {
    const timestamp =
      Math.floor(new Date().getTime() / 1000) + 1000000 + i * 1000;
    await network.provider.send("evm_mine", [timestamp]);
  }
}
