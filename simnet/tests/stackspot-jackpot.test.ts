
import { afterAll, beforeAll, beforeEach, describe, expect, it } from "vitest";
import fs from "fs";
import { boolCV } from "@stacks/transactions";

const accounts = simnet.getAccounts();
const address1 = accounts.get("wallet_1")!;
const address2 = accounts.get("wallet_2")!;
const address3 = accounts.get("wallet_3")!;
const address4 = accounts.get("wallet_4")!;
const address5 = accounts.get("wallet_5")!;

/*
  The test below is an example. To learn more, read the testing documentation here:
  https://docs.hiro.so/stacks/clarinet-js-sdk
*/

describe("initializations tests", () => {
  afterAll(()=>{
    let txReceipt = simnet.deployContract(
      "stackspot-jackpot",
      fs.readFileSync('contracts/stackspot-jackpot.clar').toString(),
      {
        clarityVersion: 3
      },
      address1
    )
    expect(txReceipt.result).toBeOk(boolCV(false))
  })

  // it("shows an example", () => {
  //   const { result } = simnet.callReadOnlyFn("stackspot-jackpot", "validate-can-claim-pot", [], address1);
  //   expect(result).toBeBool(false);
  // });

});