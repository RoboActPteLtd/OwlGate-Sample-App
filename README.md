# owlgate-sample-app

[![CI](https://github.com/RoboActPteLtd/OwlGate-Sample-App/actions/workflows/ci.yml/badge.svg)](https://github.com/RoboActPteLtd/OwlGate-Sample-App/actions/workflows/ci.yml)

The **System Under Test** for OwlGate. A deliberately small web app — a contact
form backed by a tiny API — seeded with **intentional fragility** so every OwlGate
capability has something real to act on during the demo.

This is the *specimen*, not the product. Keep it small.

## Stack

- **SvelteKit** (frontend + API routes), TypeScript.
- A handful of UI + API tests, mirrored as Test Cloud specs in
  [`owlgate-platform/tests`](../owlgate-platform/tests).

## Run

```bash
npm install
npm run dev        # dev server (http://localhost:5173)
npm run check      # svelte-check type-check
npm run build      # production build (adapter-node)
npm run preview    # run the built server (node build, http://localhost:3000)
npm test           # Vitest unit tests
npm run test:e2e   # Playwright e2e (the fragile UI suite — OwlGate's heal target)
```

## The point: seeded fragility

OwlGate is only interesting if there is something to catch and heal. See
[`FRAGILITY.md`](./FRAGILITY.md) for exactly what is broken and which OwlGate
capability each defect exercises (fragile selector → self-heal; flaky timing →
flaky detection; validation change → risk + gate).

## License

[Apache 2.0](./LICENSE)

## Running locally

The dev server listens on port 3000 by default (`npm run dev`). Set `PORT` if you
need a different one.
