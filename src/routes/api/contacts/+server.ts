import { json, error } from "@sveltejs/kit";
import type { RequestHandler } from "./$types";
import { validateContact } from "$lib/validation";

export const POST: RequestHandler = async ({ request }) => {
  const body = await request.json();
  const message = validateContact(body);
  if (message) {
    throw error(400, message);
  }
  // The sample app does not persist anything — it only needs to behave.
  return json({ ok: true }, { status: 201 });
};
