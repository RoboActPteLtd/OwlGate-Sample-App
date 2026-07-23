// Toy authentication for the sample app — the "security-sensitive" surface that
// OwlGate's gate always routes to a human (the api/login suite is tagged `auth`).
// In a real app this would verify a password hash / session; here it's a stub.

export interface Credentials {
  username?: unknown;
  password?: unknown;
}

const DEMO_USER = "admin";
const DEMO_PASSWORD = "correct-horse-battery-staple";

/** Returns true when the credentials are valid. */
export function checkCredentials(input: Credentials): boolean {
  return (
    typeof input.username === "string" &&
    typeof input.password === "string" &&
    input.username.trim().toLowerCase() === DEMO_USER &&
    input.password === DEMO_PASSWORD
  );
}
