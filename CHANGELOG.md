# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Security

- Harden the OwlGate gate workflow against GitHub Actions template injection: the PR
  base branch is now passed via a `BASE_REF` environment variable instead of
  expanding `${{ github.base_ref }}` directly into the `run` shell command.

### Added

- Initial scaffold of the OwlGate sample app (System Under Test).
- `FRAGILITY.md` documenting the seeded defects and the capability each exercises.
- Real, building **SvelteKit app** (adapter-node, runnable for Test Cloud): home +
  contact form, with email validation extracted to `$lib/validation` and unit-tested
  with **Vitest** (6 tests); type-checked clean with `svelte-check`; Playwright e2e
  config for the fragile UI suite (run separately, not in unit CI).
- GitHub Actions CI — type-check + build + Vitest unit tests; gitleaks secret scan.
- **OwlGate release gate** (`.github/workflows/owlgate-gate.yml` + `.github/owlgate/gate.sh`)
  — on every PR, computes the diff and sends it to the OwlGate coded agent on UiPath
  (client-credentials auth), polls the job, and **fails the check on a no-go** so the
  merge is blocked. Skips neutrally until the UiPath secrets are set. See
  [`OWLGATE-CI.md`](./OWLGATE-CI.md).
- **Auth endpoint + risk catalogue for a realistic block demo** — a toy `/api/login`
  (`src/routes/api/login`, `src/lib/auth.ts`) and `owlgate-catalogue.json` that tags
  the login area `auth` (severity 1.0). The gate now sends this catalogue with the
  diff, so **any change to the login code trips a no-go (needs human)** and blocks the
  PR — verified by a live job (risk 0.53). Step-by-step in [`DEMO.md`](./DEMO.md).
- **Line/function-level review targets** — the gate now sends the diff **hunks**
  (`.github/owlgate/build-diff.py` extracts the changed line ranges + enclosing
  function from `git diff`), so OwlGate names the **exact function + lines** to
  review. They're printed in the gate log and added to the PR check summary.

### Changed

- Relicensed from MIT to Apache 2.0.
