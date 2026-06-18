# Demo OwlGate in 2 minutes

Two demos, both done **entirely in the GitHub web UI** (no terminal). Everything
happens on this repo (`OwlGate-Sample-App`). The gate runs on **pull requests**.

---

## ⭐ Demo 1 — a risky change is BLOCKED (the good one)

Changing the **login (auth) code** is security-sensitive, so OwlGate always routes
it to a human → the PR is **blocked**.

1. Go to **`src/routes/api/login/+server.ts`** in this repo on GitHub.
2. Click the ✏️ **pencil** (Edit).
3. Change the one line:
   ```
   throw error(401, "invalid credentials");
   ```
   to (any wording — the point is you edited auth code):
   ```
   throw error(401, "wrong username or password");
   ```
4. Click **Commit changes…** → choose **"Create a new branch … and start a pull
   request"** → **Propose changes** → **Create pull request**.
5. On the PR, watch the **OwlGate release gate** check at the bottom. After ~30s it
   turns **red ❌**: *no-go — change risk above threshold (auth)*.
6. The **Merge button is blocked**: "Required check must pass."

→ OwlGate stopped a security-sensitive change until a human approves. ✅ That's the gate.

---

## Demo 2 — a safe change is ALLOWED

1. Edit **`README.md`** (any tiny change) with the ✏️ pencil.
2. Create a new branch + pull request (same as above).
3. The **OwlGate release gate** turns **green ✅** (verdict: go) and the **Merge
   button is enabled**.

→ A harmless change sails through.

---

## Where to look
- On the PR: the checks box → **"Details"** next to *OwlGate release gate* shows the
  live log (`authenticated → started job → verdict`).
- In UiPath: Orchestrator → **Shared** folder → **Jobs** — you'll see the real job
  that ran for your PR.

## Cleanup
These are throwaway PRs — click **Close pull request** (don't merge) when done, and
delete the branch if asked.

## Why login blocks but a typo doesn't
OwlGate scores each change's risk. The login area is tagged **`auth` (severity 1.0)**
in [`owlgate-catalogue.json`](./owlgate-catalogue.json), so even a one-line change
there crosses the "needs a human" line. A README typo touches nothing risky, so it
passes. (Today the verdict is driven by *risk*; once Test Cloud execution is wired,
real failing tests will also produce a no-go.)
