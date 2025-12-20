import { describe, it, expect } from "vitest";
import { Cl, hexToCV, UIntCV } from "@stacks/transactions";
import { hexToBytes } from "@stacks/common";

describe("stackspot-vrf", () => {
  it("should extract lower 16 bytes in little-endian format", async () => {
    const accounts = simnet.getAccounts();
    const deployer = accounts.get("deployer")!;

    // Test with a known 32-byte buffer
    const testBuffer = hexToBytes(
      "000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f"
    );

    const result = simnet.callReadOnlyFn(
      "stackspot-vrf",
      "lower-16-le",
      [Cl.buffer(testBuffer)],
      deployer
    );

    // The lower 16 bytes should be the last 16 bytes of the buffer
    const expectedLower16 = hexToBytes("101112131415161718191a1b1c1d1e1f");

    expect(result.result).toBeBuff(expectedLower16);
  });

  it("should return correct buffer from lower-16-le bytes", async () => {
    const accounts = simnet.getAccounts();
    const deployer = accounts.get("deployer")!;

    // Test with zeros in upper bytes and 0x01 at start of lower 16 bytes
    const testBuffer = hexToBytes(
      "0000000000000000000000000000000001000000000000000000000000000000"
    );

    const result = simnet.callReadOnlyFn(
      "stackspot-vrf",
      "lower-16-le",
      [Cl.buffer(testBuffer)],
      deployer
    );

    // Lower 16 bytes as buffer
    const expectedBuffer = hexToBytes("01000000000000000000000000000000");
    expect(result.result).toBeBuff(expectedBuffer);
  });

  it("should handle all zeros", async () => {
    const accounts = simnet.getAccounts();
    const deployer = accounts.get("deployer")!;

    const testBuffer = hexToBytes(
      "0000000000000000000000000000000000000000000000000000000000000000"
    );

    const result = simnet.callReadOnlyFn(
      "stackspot-vrf",
      "lower-16-le",
      [Cl.buffer(testBuffer)],
      deployer
    );

    const expectedBuffer = hexToBytes("00000000000000000000000000000000");
    expect(result.result).toBeBuff(expectedBuffer);
  });

  it("should handle max value in lower 16 bytes", async () => {
    const accounts = simnet.getAccounts();
    const deployer = accounts.get("deployer")!;

    // All 0xff in lower 16 bytes
    const testBuffer = hexToBytes(
      "00000000000000000000000000000000ffffffffffffffffffffffffffffffff"
    );

    const result = simnet.callReadOnlyFn(
      "stackspot-vrf",
      "lower-16-le",
      [Cl.buffer(testBuffer)],
      deployer
    );

    const expectedBuffer = hexToBytes("ffffffffffffffffffffffffffffffff");
    expect(result.result).toBeBuff(expectedBuffer);
  });

  it("should ignore upper 16 bytes", async () => {
    const accounts = simnet.getAccounts();
    const deployer = accounts.get("deployer")!;

    // Different upper bytes, same lower bytes should give same result
    const testBuffer1 = hexToBytes(
      "ffffffffffffffffffffffffffffffff0a000000000000000000000000000000"
    );
    const testBuffer2 = hexToBytes(
      "000000000000000000000000000000000a000000000000000000000000000000"
    );

    const result1 = simnet.callReadOnlyFn(
      "stackspot-vrf",
      "lower-16-le",
      [Cl.buffer(testBuffer1)],
      deployer
    );

    const result2 = simnet.callReadOnlyFn(
      "stackspot-vrf",
      "lower-16-le",
      [Cl.buffer(testBuffer2)],
      deployer
    );

    // Both should return the same 16-byte buffer
    const expectedBuffer = hexToBytes("0a000000000000000000000000000000");
    expect(result1.result).toBeBuff(expectedBuffer);
    expect(result2.result).toBeBuff(expectedBuffer);
  });

  it("should correctly reverse byte order for little-endian", async () => {
    const accounts = simnet.getAccounts();
    const deployer = accounts.get("deployer")!;

    // Test specific byte pattern to verify little-endian ordering
    const testBuffer = hexToBytes(
      "00000000000000000000000000000000aabbccddeeff00112233445566778899"
    );

    const result = simnet.callReadOnlyFn(
      "stackspot-vrf",
      "lower-16-le",
      [Cl.buffer(testBuffer)],
      deployer
    );

    // Lower 16 bytes extracted
    const expectedBuffer = hexToBytes("aabbccddeeff00112233445566778899");
    expect(result.result).toBeBuff(expectedBuffer);
  });

  // use timeout of 30 seconds for this test
  it(
    "should return evenly distributed random values",
    {
      timeout: 30000,
    },
    async () => {
      const accounts = simnet.getAccounts();
      const deployer = accounts.get("deployer")!;
      const winner = [];
      for (let i = 1; i <= 1000; i++) {
        const blockHeight = simnet.blockHeight;
        const result = simnet.callPublicFn(
          "stackspot-vrf",
          "get-random-uint-at-block",
          [Cl.uint(blockHeight)],
          deployer
        );
        winner.push(
          (
            hexToCV(
              simnet.runSnippet(`(mod u${result.result.value.value} u${100})`)
            ) as UIntCV
          ).value
        );
      }
      // expectation: values should be fairly evenly distributed between 0 and 99
      const distribution = Array(100).fill(0);
      winner.forEach((value) => {
        distribution[Number(value)]++;
      });
      const expectedDistribution = [
        86, 87, 124, 105, 91, 94, 99, 103, 97, 102, 90, 117, 97, 110, 109, 94,
        92, 103, 89, 104, 116, 82, 118, 93, 130, 81, 88, 107, 104, 109, 87, 92,
        98, 104, 103, 92, 103, 100, 90, 100, 83, 101, 95, 113, 118, 118, 93,
        108, 107, 95, 86, 78, 92, 113, 99, 111, 73, 105, 110, 123, 105, 91, 95,
        94, 97, 84, 93, 107, 105, 107, 106, 118, 89, 85, 113, 95, 96, 105, 95,
        101, 94, 88, 89, 112, 122, 104, 114, 82, 99, 96, 106, 109, 90, 104, 112,
        116, 94, 103, 93, 81,
      ];
      expect(distribution).toEqual(expectedDistribution);
    }
  );
});
