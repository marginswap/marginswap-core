import { expect, assert } from "chai";
import { ethers, deployments, getNamedAccounts } from "hardhat";
import ERC20PresetMinterPauser from "@openzeppelin/contracts/build/contracts/ERC20PresetMinterPauser.json";

const WITHDRAWER = 1;

async function makeTestToken() {
  const Token = await ethers.getContractFactory(
    ERC20PresetMinterPauser.abi,
    ERC20PresetMinterPauser.bytecode
  );
  const token = await Token.deploy("MFITestToken", "MFITT");
  await token.deployed();
  return token;
}

async function getFund() {
  const Fund = await deployments.get("Fund");
  const fund = await ethers.getContractAt("Fund", Fund.address);
  return fund;
}

describe("Funds.activateToken", function () {
  beforeEach(async () => {
    await deployments.fixture();
  });
  it("should allow a valid activator to activate and deactivate a token", async function () {
    const token = await makeTestToken();

    const fund = await getFund();
    await fund.activateToken(token.address);

    expect(await fund.activeTokens(token.address)).to.equal(true);

    await fund.deactivateToken(token.address);

    expect(await fund.activeTokens(token.address)).to.equal(false);
  });

  it("should handle deposits and withdrawals", async () => {
    const token = await makeTestToken();
    const fund = await getFund();
    const { deployer } = await getNamedAccounts();

    // before token activation or withdrawer role
    expect(fund.deposit(token.address, 1000)).to.be.reverted;

    await fund.activateToken(token.address);

    // before withdrawer role
    expect(fund.depositFor(deployer, token.address, 1000)).to.be.reverted;

    const roles = await deployments
      .get("Roles")
      .then((Roles) => ethers.getContractAt("Roles", Roles.address));

    await roles.giveRole(WITHDRAWER, deployer);
    await token.mint(deployer, 100000000);

    expect(await token.balanceOf(deployer)).to.equal(100000000);
    await token.approve(fund.address, 10000);

    await fund.updateRoleCache(WITHDRAWER, deployer);
    // with everything in place
    await fund.depositFor(deployer, token.address, 1000);
    expect(await token.balanceOf(fund.address)).to.equal(1000);

    const balanceBeforeWithdraw = await token.balanceOf(deployer);

    await fund.withdraw(token.address, deployer, 500);

    expect(await token.balanceOf(deployer)).to.equal(
      balanceBeforeWithdraw.add(500)
    );
  });
});
