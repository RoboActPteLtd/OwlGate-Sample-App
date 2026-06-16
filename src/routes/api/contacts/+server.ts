import { json, error } from "@sveltejs/kit";
import type { RequestHandler } from "./$types";

// Defect #3 (breaking change): this validation rule was *tightened* in the demo
// PR — it now rejects addresses without a dot in the domain (e.g. "a@b"), which
// older tests assumed were valid. This is a genuine behaviour change, so OwlGate's
// Gate agent should route it to a human rather than auto-passing it.
const EMAIL = /^[^@\s]+@[^@\s]+\.[^@\s]+$/;

export const POST: RequestHandler = async ({ request }) => {
  const { name, email } = await request.json();

  if (!name || typeof name !== "string") {
    throw error(400, "name is required");
  }
  if (!email || !EMAIL.test(email)) {
    throw error(400, "a valid email is required");
  }

  // The sample app does not persist anything — it only needs to behave.
  return json({ ok: true }, { status: 201 });
};
