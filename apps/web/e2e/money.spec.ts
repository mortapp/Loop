import { test, expect } from "@playwright/test";
import { hasQaCredentials } from "../playwright.config";

test.describe("Money", () => {
  test.beforeEach(() => {
    test.skip(!hasQaCredentials, "requires QA_TEST_EMAIL/QA_TEST_PASSWORD");
  });

  test("logging a manual entry appears in the ledger and moves the totals", async ({ page }) => {
    await page.goto("/money");

    const madeBefore = await page.getByText("MADE").locator("..").getByText(/^\$/).textContent();

    await page.getByText("Add entry", { exact: true }).click();
    const description = `E2E manual entry ${Date.now()}`;
    await page.locator('select[name="kind"]').selectOption("earn");
    await page.getByPlaceholder("$ amount").fill("12.34");
    await page.getByPlaceholder(/description/i).fill(description);
    await page.getByRole("button", { name: /^log entry$/i }).click();

    await expect(page.getByText(description)).toBeVisible();

    const madeAfter = await page.getByText("MADE").locator("..").getByText(/^\$/).textContent();
    expect(madeAfter).not.toBe(madeBefore);
  });

  test("Purchases & returns (Protect) is reachable from Money", async ({ page }) => {
    await page.goto("/money");
    await page.getByRole("link", { name: /purchases.*returns/i }).click();
    await expect(page).toHaveURL(/\/money\/purchases$/);
  });
});
