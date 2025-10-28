import { tx } from "@hirosystems/clarinet-sdk";
import { boolCV, uintCV } from "@stacks/transactions";
import { principal } from "@stacks/transactions/dist/cl";
import fs from "fs";
import { beforeEach, describe, expect, it } from "vitest";

const accounts = simnet.getAccounts();
const address1 = accounts.get("wallet_1")!;
const address2 = accounts.get("wallet_2")!;

/*
  The test below is an example. To learn more, read the testing documentation here:
  https://docs.hiro.so/stacks/clarinet-js-sdk
*/

describe("join-pot", () => {
  beforeEach(() => {
    let txReceipt = simnet.deployContract(
      "stackpot2",
      fs.readFileSync("contracts/stackpot.clar").toString(),
      null,
      address1
    );
    expect(txReceipt.result).toBeOk(boolCV(true));
  });

  it("user can join pot once", () => {
    let txReceipt = simnet.callPublicFn(
      `${address1}.stackpot2`,
      "join-pot",
      [uintCV(10000000), principal(address2)],
      address2
    );
    expect(txReceipt.result).toBeOk(boolCV(true));

    txReceipt = simnet.callPublicFn(
      `${address1}.stackpot2`,
      "join-pot",
      [uintCV(20000000), principal(address2)],
      address2
    );
    expect(txReceipt.result).toBeErr(uintCV(110)); // already joined
  });
  it("tx sender required as argument", () => {
    let txReceipt = simnet.callPublicFn(
      `${address1}.stackpot2`,
      "join-pot",
      [uintCV(20000000), principal(address1)],
      address2
    );
    expect(txReceipt.result).toBeErr(uintCV(102)); // wrong user
  });

  it("user can't join with less than minimum", () => {
    let txReceipt = simnet.callPublicFn(
      `${address1}.stackpot2`,
      "join-pot",
      [uintCV(1), principal(address2)],
      address2
    );
    expect(txReceipt.result).toBeErr(uintCV(109)); // below minimum
  });

  it("pot owner cannot join pot", () => {
    let txReceipt = simnet.callPublicFn(
      `${address1}.stackpot2`,
      "join-pot",
      [uintCV(10000000), principal(address1)],
      address1
    );
    expect(txReceipt.result).toBeErr(uintCV(102)); // unauthorized participant (owner)
  });

  it("platform address cannot join pot", () => {
    // platform address from contract
    const platformAddress = "ST1SJ3DTE5DN7X54YDH5D64R3BCB6A2AG2ZQ8YPD5";
    let txReceipt = simnet.callPublicFn(
      `${address1}.stackpot2`,
      "join-pot",
      [uintCV(10000000), principal(platformAddress)],
      platformAddress
    );
    expect(txReceipt.result).toBeErr(uintCV(102)); // unauthorized participant (platform)
  });

  it("pot treasury address cannot join pot", () => {
    // pot treasury address is contract address
    const potTreasuryAddress = `${address1}.stackpot2`;
    let txReceipt = simnet.callPublicFn(
      `${address1}.stackpot2`,
      "join-pot",
      [uintCV(10000000), principal(potTreasuryAddress)],
      address2
    );
    expect(txReceipt.result).toBeErr(uintCV(102)); // unauthorized participant (treasury)
  });

  it("cannot join pot when locked", () => {
    // Lock the pot
    // TODO
    let txReceipt = simnet.callPublicFn(
      `${address1}.stackpot2`,
      "join-pot",
      [uintCV(10000000), principal(address2)],
      address2
    );
    // expect(txReceipt.result).toBeErr(uintCV(103)); // delegate locked
  });

  it("cannot join pot with insufficient balance", () => {
    // Simulate address with low balance
    simnet.transferSTX(100_000_000_000_000 - 1, address1, address2);
    let txReceipt = simnet.callPublicFn(
      `${address1}.stackpot2`,
      "join-pot",
      [uintCV(100000), principal(address2)],
      address2
    );
    expect(txReceipt.result).toBeErr(uintCV(100)); // insufficient balance
  });
});
