# Seeded fragility

Deliberate defects in this sample app, each mapped to the OwlGate capability it
demonstrates. **Do not "fix" these casually** — they are the demo.

| # | Defect | Where | OwlGate capability it exercises |
| :-- | :--- | :--- | :--- |
| 1 | **Fragile selector** — the success toast is targeted by a brittle locator that breaks when the label text changes. | `src/lib/Toast.svelte` + `ui/contact-form` test | **Self-Healing agent** repairs the locator and re-runs. |
| 2 | **Flaky timing** — the toast animates in; a too-short wait makes the assertion intermittently fail. | `src/routes/contact/+page.svelte` | **Flaky detection** flags it before it blocks a release. |
| 3 | **Breaking change** — a tightened email-validation rule rejects inputs the old tests assumed valid. | `src/routes/api/contacts/+server.ts` | **Risk agent** scores it high; **Gate agent** routes to the human. |

## Demo choreography

- Land a PR that touches #3 → Risk agent flags high risk → selected suites run →
  the #1 selector test fails → Self-Healing agent fixes it → Gate agent issues a
  **no-go pending human** because #3 is a genuine behaviour change → approver
  decides at the Action Center gate.
