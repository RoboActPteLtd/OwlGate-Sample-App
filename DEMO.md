# Demo OwlGate in 2 minutes

Two demos, both done **entirely in the GitHub web UI** (no terminal). Everything
happens on this repo (`OwlGate-Sample-App`). The gate runs on **pull requests**.

---

## ⭐ Demo 1 — a risky change is BLOCKED, and OwlGate names the function

Changing the **login (auth) code** is security-sensitive, so OwlGate routes it to a
human → the PR is **blocked**, and it tells the reviewer the exact function to look at.

1. Go to **`src/lib/auth.ts`** in this repo on GitHub.
2. Click the ✏️ **pencil** (Edit).
3. Make a realistic one-line change inside `checkCredentials` — e.g. make the login
   case-insensitive. Change:
   ```
   input.username === DEMO_USER &&
   ```
   to:
   ```
   input.username.trim().toLowerCase() === DEMO_USER &&
   ```
4. **Commit changes…** → choose **"Create a new branch … and start a pull request"** →
   **Propose changes** → **and click the green "Create pull request" button** (this last
   step is easy to miss — without it there's no PR and nothing runs).
5. On the PR, the **OwlGate release gate** check turns **red ❌** after ~30s. Its
   summary shows the exact code to review:
   > 🦉 OwlGate — code to review
   > • `checkCredentials`  [src/lib/auth.ts:15-21]
6. The **Merge button is blocked**: "Required check must pass."

→ OwlGate stopped a security-sensitive change **and pointed the reviewer at the exact
function** — not just "this PR is risky." ✅ That's the gate.

---

## Demo 2 — a safe change is ALLOWED

1. Edit **`README.md`** (any tiny change) with the ✏️ pencil.
2. Create a new branch + pull request (same as above).
3. The **OwlGate release gate** turns **green ✅** (verdict: go) and the **Merge
   button is enabled**.

→ A harmless change sails through.

---

## Where to look
- On the PR: the **check summary** for *OwlGate release gate* lists the function +
  line range to review; **"Details"** shows the live log (`built diff with hunks →
  authenticated → started job → verdict → review these`).
- In UiPath: Orchestrator → **Shared** folder → **Jobs** — you'll see the real job
  that ran for your PR (open it for the Input/Output arguments).

## Cleanup
These are throwaway PRs — click **Close pull request** (don't merge) when done, and
delete the branch if asked.

## Why login blocks but a typo doesn't
OwlGate scores each change's risk. The login area is tagged **`auth` (severity 1.0)**
in [`owlgate-catalogue.json`](./owlgate-catalogue.json), so even a one-line change
there crosses the "needs a human" line. A README typo touches nothing risky, so it
passes. The gate also reads the diff's **hunks** (line ranges + enclosing function),
which is how it names `checkCredentials` instead of just `auth.ts`. (Today the verdict
is driven by *risk*; once Test Cloud execution is wired, real failing tests will also
produce a no-go.)
