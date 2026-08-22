import { defineConfig, devices } from "@playwright/test";

// QA credentials for a real, isolated Supabase test account -- never
// committed (see .env.local.example / CI secrets). Tests that need a
// signed-in session skip themselves (test.skip) when these are absent,
// rather than failing CI before the owner has provisioned a QA account.
// See e2e/auth.setup.ts for how the session is established, and
// docs/KNOWN_ISSUES.md for the OWNER_ACTION_REQUIRED tracking entry.
export const hasQaCredentials = Boolean(process.env.QA_TEST_EMAIL && process.env.QA_TEST_PASSWORD);

export const AUTH_FILE = "e2e/.auth/qa-user.json";

export default defineConfig({
  testDir: "./e2e",
  fullyParallel: true,
  forbidOnly: Boolean(process.env.CI),
  retries: process.env.CI ? 1 : 0,
  reporter: process.env.CI ? [["github"], ["html", { open: "never" }]] : "list",
  use: {
    baseURL: process.env.PLAYWRIGHT_BASE_URL ?? "http://localhost:3000",
    trace: "on-first-retry",
  },
  projects: hasQaCredentials
    ? [
        // Real sign-in via the actual /sign-in form, saved once and reused
        // -- never a production auth bypass. See e2e/auth.setup.ts.
        { name: "setup", testMatch: /auth\.setup\.ts/, use: { ...devices["Desktop Chrome"] } },
        {
          name: "chromium",
          use: { ...devices["Desktop Chrome"], storageState: AUTH_FILE },
          dependencies: ["setup"],
        },
      ]
    : [
        // No QA credentials: only guard/public specs run (they test.skip
        // themselves out when they need a signed-in session).
        { name: "chromium", use: { ...devices["Desktop Chrome"] } },
      ],
  webServer: {
    command: "npm run dev",
    url: "http://localhost:3000",
    reuseExistingServer: !process.env.CI,
    timeout: 120_000,
  },
});
