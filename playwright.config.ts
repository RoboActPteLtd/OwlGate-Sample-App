import { defineConfig } from "@playwright/test";

// The fragile UI suite (tests/*.spec.ts) is the OwlGate self-healing target — see
// FRAGILITY.md. It is NOT run in this repo's CI (which runs unit tests only); it is
// exercised by the OwlGate pipeline against a deployed build.
export default defineConfig({
  testDir: "tests",
  testMatch: "**/*.spec.ts",
  use: { baseURL: "http://localhost:3000" },
  webServer: {
    command: "npm run build && node build",
    port: 3000,
    reuseExistingServer: !process.env.CI,
  },
});
