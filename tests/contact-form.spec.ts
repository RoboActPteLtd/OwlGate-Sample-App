import { test, expect } from "@playwright/test";

// Mirrors owlgate-platform/tests/ui/contact-form.spec.md.
// Contains the seeded fragility on purpose — see FRAGILITY.md.
test("submitting the contact form shows a success toast", async ({ page }) => {
  await page.goto("/contact");
  await page.fill('input[name="name"]', "Ada Lovelace");
  await page.fill('input[name="email"]', "ada@example.com");
  await page.click('button[type="submit"]');

  // Defect #1: brittle locator. Self-Healing agent rewrites this to a stable
  // selector (e.g. role=status) when the markup changes.
  await expect(page.locator(".toast-success > span")).toHaveText(
    "Thanks, we'll be in touch",
  );
});
