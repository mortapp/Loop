import { test, expect } from "@playwright/test";
import AxeBuilder from "@axe-core/playwright";
import { hasQaCredentials } from "../playwright.config";

/**
 * Automated WCAG2A/2AA scans via axe-core. This catches structural
 * issues (missing accessible names, contrast, landmarks, ARIA misuse)
 * automatically; it doesn't replace manual keyboard/screen-reader
 * passes -- see docs/KNOWN_ISSUES.md for what's still manual-only.
 */
test.describe("accessibility (public pages, no auth needed)", () => {
  test.use({ storageState: { cookies: [], origins: [] } });

  for (const path of ["/sign-in", "/sign-up"]) {
    test(`${path} has no automatically detectable violations`, async ({ page }) => {
      await page.goto(path);
      const results = await new AxeBuilder({ page }).withTags(["wcag2a", "wcag2aa"]).analyze();
      expect(results.violations, JSON.stringify(results.violations, null, 2)).toEqual([]);
    });
  }
});

test.describe("accessibility (authenticated pages)", () => {
  test.beforeEach(() => {
    test.skip(!hasQaCredentials, "requires QA_TEST_EMAIL/QA_TEST_PASSWORD");
  });

  for (const path of ["/today", "/money", "/sell", "/business", "/ai", "/profile", "/settings"]) {
    test(`${path} has no automatically detectable violations`, async ({ page }) => {
      await page.goto(path);
      const results = await new AxeBuilder({ page }).withTags(["wcag2a", "wcag2aa"]).analyze();
      expect(results.violations, JSON.stringify(results.violations, null, 2)).toEqual([]);
    });
  }
});
