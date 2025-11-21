import { Cl } from "@stacks/transactions";
import fs from "fs";
import { beforeEach, describe, expect, it } from "vitest";

const accounts = simnet.getAccounts();
const address1 = accounts.get("wallet_1")!;
const address2 = accounts.get("wallet_2")!;

describe("join-pot", () => {
  beforeEach(() => {
    let txReceipt = simnet.deployContract(
      "stackpot2",
      fs.readFileSync("contracts/stackspot-jackpot.clar").toString(),
      {clarityVersion: 3},
      address1
    );
    expect(txReceipt.result).toBeOk(Cl.bool(true));
  });

  it("user can join pot once", () => {
    let txReceipt = simnet.callPublicFn(
      `${address1}.stackpot2`,
      "join-pot",
      [Cl.uint(10000000), Cl.principal(address2)],
      address2
    );
    expect(txReceipt.result).toBeOk(Cl.bool(true));

    txReceipt = simnet.callPublicFn(
      `${address1}.stackpot2`,
      "join-pot",
      [Cl.uint(20000000), Cl.principal(address2)],
      address2
    );
    expect(txReceipt.result).toBeErr(Cl.uint(1104)); // already joined
  });
  it("tx sender required as argument", () => {
    let txReceipt = simnet.callPublicFn(
      `${address1}.stackpot2`,
      "join-pot",
      [Cl.uint(20000000), Cl.principal(address1)],
      address2
    );
    expect(txReceipt.result).toBeErr(Cl.uint(1105)); // wrong user
  });

  it("user can't join with less than minimum", () => {
    let txReceipt = simnet.callPublicFn(
      `${address1}.stackpot2`,
      "join-pot",
      [Cl.uint(1), Cl.principal(address2)],
      address2
    );
    expect(txReceipt.result).toBeErr(Cl.uint(1302)); // below minimum
  });

  it("pot owner cannot join pot", () => {
    let txReceipt = simnet.callPublicFn(
      `${address1}.stackpot2`,
      "join-pot",
      [Cl.uint(10000000), Cl.principal(address1)],
      address1
    );
    expect(txReceipt.result).toBeErr(Cl.uint(1101)); // unauthorized participant (owner)
  });

  it("platform address cannot join pot", () => {
    // platform address from contract
    const platformAddress = "ST1SJ3DTE5DN7X54YDH5D64R3BCB6A2AG2ZQ8YPD5";
    let txReceipt = simnet.callPublicFn(
      `${address1}.stackpot2`,
      "join-pot",
      [Cl.uint(10000000), Cl.principal(platformAddress)],
      platformAddress
    );
    expect(txReceipt.result).toBeErr(Cl.uint(1101)); // unauthorized participant (platform)
  });

  it("pot treasury address cannot join pot", () => {
    // pot treasury address is contract address
    const potTreasuryAddress = `${address1}.stackpot2`;
    let txReceipt = simnet.callPublicFn(
      `${address1}.stackpot2`,
      "join-pot",
      [Cl.uint(10000000), Cl.principal(potTreasuryAddress)],
      address2
    );
    expect(txReceipt.result).toBeErr(Cl.uint(1105)); // unauthorized participant (treasury)
  });

  it("cannot join pot when locked", () => {
    // Lock the pot
    // TODO
    let txReceipt = simnet.callPublicFn(
      `${address1}.stackpot2`,
      "join-pot",
      [Cl.uint(10000000), Cl.principal(address2)],
      address2
    );
    // expect(txReceipt.result).toBeErr(Cl.uint(103)); // delegate locked
  });

  it("cannot join pot with insufficient balance", () => {
    // Simulate address with low balance
    simnet.transferSTX(100_000_000_000_000 - 1, address1, address2);
    let txReceipt = simnet.callPublicFn(
      `${address1}.stackpot2`,
      "join-pot",
      [Cl.uint(100000), Cl.principal(address2)],
      address2
    );
    expect(txReceipt.result).toBeErr(Cl.uint(1408)); // insufficient balance
  });
});