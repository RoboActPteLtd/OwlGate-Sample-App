# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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

### Changed

- Relicensed from MIT to Apache 2.0.
