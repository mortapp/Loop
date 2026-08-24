import { test, expect } from "@playwright/test";
import { hasQaCredentials } from "../playwright.config";

test.describe("Sell", () => {
  test.beforeEach(() => {
    test.skip(!hasQaCredentials, "requires QA_TEST_EMAIL/QA_TEST_PASSWORD");
  });

  test("adding an item makes it appear in the owned list", async ({ page }) => {
    await page.goto("/sell");

    const name = `E2E Item ${Date.now()}`;
    await page.getByText("Add item", { exact: true }).click();
    await page.getByPlaceholder("Item name").fill(name);
    await page.getByPlaceholder("Category (optional)").fill("Electronics");
    await page.getByRole("button", { name: /add item/i }).click();

    await expect(page.getByText(name)).toBeVisible();
  });
});
