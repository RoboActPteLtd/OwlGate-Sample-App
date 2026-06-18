# OwlGate release gate (CI)

This repo's pull requests are gated by **OwlGate** running on UiPath. On every PR,
a GitHub Action computes the diff, sends it to the OwlGate coded agent, waits for
the **go / no-go** verdict, and **fails the check on a no-go** — so a bad change
can't be merged.

- Workflow: [`.github/workflows/owlgate-gate.yml`](.github/workflows/owlgate-gate.yml)
- Logic: [`.github/owlgate/gate.sh`](.github/owlgate/gate.sh)

## How it works

```
PR opened
  └─ git diff --numstat  →  { "diff": [ {path, lines}, … ] }
       └─ POST to UiPath Orchestrator (StartJobs → owlgate-gate)
            └─ agent: select → (execute) → heal → decide
                 └─ poll the job → read verdict
                      └─ go  → check passes ✅   |   no-go → check fails ❌ (merge blocked)
```

It authenticates as a **UiPath External Application** (machine-to-machine, client
credentials) — no human login — and resolves the folder + release at runtime, so it
keeps working across redeploys.

## One-time setup (already done, recorded here for the next person)

1. **UiPath → Admin → External Applications → Add Application**
   - Confidential application; **Application scope** `OR.Jobs` on *Orchestrator API Access*
     (no User scopes; Redirect URL left blank).
   - Copy the **App ID** and **App Secret**.
2. **GitHub → this repo → Settings → Secrets and variables → Actions**, add:
   - `UIPATH_CLIENT_ID` = App ID
   - `UIPATH_CLIENT_SECRET` = App Secret
3. **To actually block merges:** Settings → Branches → branch protection on `main` →
   require the **"OwlGate release gate / gate"** status check.

Tenant config lives as plain `env:` in the workflow (`UIPATH_ACCOUNT`,
`UIPATH_TENANT`, `UIPATH_FOLDER_ID`, `UIPATH_RELEASE_KEY`). The folder id + release
key are used directly so the app needs **only the `OR.Jobs` scope** (no
`OR.Folders.Read`/`OR.Execution.Read`). **If you redeploy the agent, update
`UIPATH_RELEASE_KEY`** (`uip or processes list --folder-path Shared` → `Key`).

> Before the secrets are set, the workflow **skips** (neutral pass) so it never
> blocks PRs prematurely.

## Honest caveats

- **Test Cloud is still stubbed.** The PR sends only the *diff*, not test results.
  The agent's runner currently returns "pass" for any suite it isn't told failed,
  so a real PR will usually come back **go** (or `needs_human` if the change is
  high-risk). The end-to-end *plumbing* — PR → UiPath → verdict → PR check — is real;
  real red/green from actual tests needs Test Manager + a real `TestRunner`
  implementation wired in (the interface already exists in `owlgate-agents`).
- **First PR is the live test.** Watch the Action logs. Common fixes:
  - `auth failed` / `no access_token` → the app has no `OR.Jobs` *Application*
    scope, or the wrong identity URL.
  - `start-job failed (HTTP 403)` → the External Application is authenticated but
    not authorised in the `Shared` folder — grant it access (Tenant → Manage Access,
    or add it to the folder).
  - `start-job failed (HTTP 404)` → the `UIPATH_RELEASE_KEY` is stale (you redeployed);
    refresh it from `uip or processes list --folder-path Shared`.
  - Verbose HTTP status + the UiPath error body are printed on any failure, so the
    Action log tells you exactly which call broke.
