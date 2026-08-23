import { test as setup, expect } from "@playwright/test";
import { AUTH_FILE } from "../playwright.config";

/**
 * Signs in through the real /sign-in form using a dedicated QA Supabase
 * account (QA_TEST_EMAIL / QA_TEST_PASSWORD -- never committed, see
 * .env.local.example and docs/KNOWN_ISSUES.md) and saves the resulting
 * session as storage state for every other authenticated spec to reuse.
 * This is a real login through the product's own auth flow, not a
 * bypass -- see CLAUDE.md's "no production auth bypass" requirement.
 *
 * playwright.config.ts only registers this project (and the ones that
 * depend on it) when both env vars are present, so this file never runs
 * -- and never fails CI -- without them.
 */
setup("authenticate as the QA user", async ({ page }) => {
  const email = process.env.QA_TEST_EMAIL!;
  const password = process.env.QA_TEST_PASSWORD!;

  await page.goto("/sign-in");
  await page.getByLabel(/email/i).fill(email);
  await page.getByLabel(/password/i).fill(password);
  await page.getByRole("button", { name: /sign in/i }).click();

  // A brand-new QA account (profiles.display_name still null) lands on
  // the one-time onboarding step first -- see /auth/complete-profile.
  // An account that's already been through it once goes straight to
  // /today. Handle both so this setup doesn't need updating the moment
  // the QA account first gets created.
  await page.waitForURL(/\/(today|auth\/complete-profile)$/);
  if (page.url().includes("/auth/complete-profile")) {
    await page.getByRole("button", { name: /continue/i }).click();
    await page.waitForURL("/today");
  }
  await expect(page.getByRole("heading", { name: "Today" })).toBeVisible();

  await page.context().storageState({ path: AUTH_FILE });
});
