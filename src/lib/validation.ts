// Contact validation — extracted so it is pure and unit-testable in node.
//
// Defect #3 (breaking change) lives here: the email rule was *tightened* in the
// demo PR to require a dot in the domain, so addresses like "a@b" that older tests
// assumed valid are now rejected. This is a genuine behaviour change — OwlGate's
// RiskAgent scores it high and the GateAgent routes it to a human.

export const EMAIL = /^[^@\s]+@[^@\s]+\.[^@\s]+$/;

export function isValidEmail(email: unknown): email is string {
  return typeof email === "string" && EMAIL.test(email);
}

export interface ContactInput {
  name?: unknown;
  email?: unknown;
}

/** Returns an error message, or `null` when the contact is valid. */
export function validateContact(input: ContactInput): string | null {
  if (!input.name || typeof input.name !== "string") {
    return "name is required";
  }
  if (!isValidEmail(input.email)) {
    return "a valid email is required";
  }
  return null;
}
