import { describe, it, expect } from "vitest";
import { checkCredentials } from "../src/lib/auth";

describe("checkCredentials", () => {
  it("accepts the valid demo credentials", () => {
    expect(
      checkCredentials({ username: "admin", password: "correct-horse-battery-staple" }),
    ).toBe(true);
  });

  it("rejects a wrong password", () => {
    expect(checkCredentials({ username: "admin", password: "nope" })).toBe(false);
  });

  it("rejects non-strings", () => {
    expect(checkCredentials({ username: 1, password: 2 })).toBe(false);
    expect(checkCredentials({})).toBe(false);
  });
});
