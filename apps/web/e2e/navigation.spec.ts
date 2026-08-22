import { test, expect } from "@playwright/test";
import { hasQaCredentials } from "../playwright.config";

/**
 * The five primary nav destinations (apps/web/src/lib/nav.ts) plus
 * Protect (one level under Money) each render their real page, not a
 * blank shell or an error boundary. Requires a signed-in QA session --
 * see e2e/auth.setup.ts and docs/KNOWN_ISSUES.md.
 */
test.describe("primary navigation", () => {
  test.beforeEach(() => {
    test.skip(!hasQaCredentials, "requires QA_TEST_EMAIL/QA_TEST_PASSWORD");
  });

  const destinations: [path: string, heading: string | RegExp][] = [
    ["/today", "Today"],
    ["/money", "Money"],
    ["/sell", "Sell"],
    ["/business", "Business"],
    ["/ai", /ask loop/i],
    ["/money/purchases", /purchases|returns/i],
  ];

  for (const [path, heading] of destinations) {
    test(`${path} renders its page`, async ({ page }) => {
      await page.goto(path);
      await expect(page).toHaveURL(new RegExp(`${path}$`));
      await expect(page.getByRole("heading", { name: heading }).first()).toBeVisible();
    });
  }

  test("the rail nav links to every primary destination", async ({ page }) => {
    await page.goto("/today");
    const nav = page.getByRole("navigation", { name: "Primary" }).first();
    for (const label of ["Today", "Money", "Sell", "Business", "AI"]) {
      await expect(nav.getByRole("link", { name: label })).toBeVisible();
    }
  });
});
