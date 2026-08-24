import { test, expect } from "@playwright/test";
import { hasQaCredentials } from "../playwright.config";

/**
 * The account identity control (apps/web/src/components/account-menu.tsx)
 * -- deliberately no billing/plan/upgrade rows, since LOOP has no
 * subscription tiers (see CLAUDE.md / docs/DECISIONS.md).
 */
test.describe("account menu", () => {
  test.beforeEach(() => {
    test.skip(!hasQaCredentials, "requires QA_TEST_EMAIL/QA_TEST_PASSWORD");
  });

  test("opens with every expected item and no billing/plan UI", async ({ page }) => {
    await page.goto("/today");

    await page
      .getByRole("button", { name: /^Account menu for/ })
      .first()
      .click();
    const menu = page.getByRole("menu", { name: "Account menu" });
    await expect(menu).toBeVisible();

    for (const item of ["Account", "Profile", "Appearance", "Help", "Sign out"]) {
      await expect(menu.getByRole("menuitem", { name: item })).toBeVisible();
    }

    for (const forbidden of [/billing/i, /upgrade/i, /\bplan\b/i, /subscription/i]) {
      await expect(menu.getByText(forbidden)).toHaveCount(0);
    }
  });

  test("closes on Escape and returns focus to the trigger", async ({ page }) => {
    await page.goto("/today");
    const trigger = page.getByRole("button", { name: /^Account menu for/ }).first();

    await trigger.click();
    await expect(page.getByRole("menu", { name: "Account menu" })).toBeVisible();

    await page.keyboard.press("Escape");
    await expect(page.getByRole("menu", { name: "Account menu" })).not.toBeVisible();
    await expect(trigger).toBeFocused();
  });

  test("Profile navigates and closes the menu", async ({ page }) => {
    await page.goto("/today");
    await page
      .getByRole("button", { name: /^Account menu for/ })
      .first()
      .click();
    await page.getByRole("menuitem", { name: "Profile" }).click();
    await expect(page).toHaveURL(/\/profile$/);
    await expect(page.getByRole("heading", { name: "Profile" })).toBeVisible();
  });
});
