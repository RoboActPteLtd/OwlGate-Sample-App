import { describe, it, expect } from "vitest";
import { isValidEmail, validateContact } from "../src/lib/validation";

describe("isValidEmail", () => {
  it("accepts a normal address", () => {
    expect(isValidEmail("ada@example.com")).toBe(true);
  });

  it("rejects a domain without a dot (the tightened rule, defect #3)", () => {
    expect(isValidEmail("a@b")).toBe(false);
  });

  it("rejects non-strings", () => {
    expect(isValidEmail(42)).toBe(false);
    expect(isValidEmail(undefined)).toBe(false);
  });
});

describe("validateContact", () => {
  it("passes a valid contact", () => {
    expect(validateContact({ name: "Ada", email: "ada@example.com" })).toBeNull();
  });

  it("requires a name", () => {
    expect(validateContact({ email: "ada@example.com" })).toBe("name is required");
  });

  it("requires a valid email", () => {
    expect(validateContact({ name: "Ada", email: "a@b" })).toBe(
      "a valid email is required",
    );
  });
});
