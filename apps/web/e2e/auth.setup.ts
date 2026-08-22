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

  await page.waitForURL("/today");
  await expect(page.getByRole("heading", { name: "Today" })).toBeVisible();

  await page.context().storageState({ path: AUTH_FILE });
});
