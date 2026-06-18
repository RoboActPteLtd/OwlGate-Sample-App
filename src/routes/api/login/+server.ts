import { json, error } from "@sveltejs/kit";
import type { RequestHandler } from "./$types";
import { checkCredentials } from "$lib/auth";

// Authentication endpoint. Any change here is security-sensitive — OwlGate's gate
// tags this area `auth` (severity 1.0), so a change routes to a human for review.
export const POST: RequestHandler = async ({ request }) => {
  const body = await request.json();
  if (!checkCredentials(body)) {
    throw error(401, "invalid credentials");
  }
  return json({ ok: true }, { status: 200 });
};
