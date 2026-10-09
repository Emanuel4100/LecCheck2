import { cloudflareTest } from "@cloudflare/vitest-pool-workers";
import { defineConfig } from "vitest/config";

export default defineConfig({
  plugins: [
    cloudflareTest({
      wrangler: { configPath: "./wrangler.jsonc" },
      miniflare: {
        bindings: {
          JWT_SECRET: "test-secret-0123456789abcdef0123456789abcdef",
          DEV_AUTH: "1",
          GOOGLE_CLIENT_ID: "test-client.apps.googleusercontent.com",
          HEALTH_TOKEN: "test-health-token",
        },
      },
    }),
  ],
});
