
import { describe, expect, it } from "vitest";

const accounts = simnet.getAccounts();
const address1 = accounts.get("wallet_1")!;

/*
  The test below is an example. To learn more, read the testing documentation here:
  https://docs.hiro.so/stacks/clarinet-js-sdk
*/

describe("example tests", () => {
  it("ensures simnet is well initialised", () => {
    expect(simnet.blockHeight).toBeDefined();
  });

  it("shows an example", () => {
    const { result } = simnet.callReadOnlyFn("stackspot-jackpot", "validate-can-claim-pot", [], address1);
    expect(result).toBeBool(false);
  });
  
});