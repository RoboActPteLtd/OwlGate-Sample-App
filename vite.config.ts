import { sveltekit } from "@sveltejs/kit/vite";
import { defineConfig } from "vitest/config";

export default defineConfig({
  plugins: [sveltekit()],
  test: {
    // Unit tests only (node). The Playwright *.spec.ts e2e suite runs separately.
    include: ["tests/**/*.test.ts"],
    environment: "node",
  },
});
