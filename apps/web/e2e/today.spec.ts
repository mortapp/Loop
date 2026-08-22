import { test, expect } from "@playwright/test";
import { hasQaCredentials } from "../playwright.config";

test.describe("Today", () => {
  test.beforeEach(() => {
    test.skip(!hasQaCredentials, "requires QA_TEST_EMAIL/QA_TEST_PASSWORD");
  });

  test("quick-add creates an action, then Done and Dismiss remove it from the open list", async ({ page }) => {
    await page.goto("/today");

    const title = `E2E quick-add ${Date.now()}`;
    await page.getByPlaceholder(/add something to do/i).fill(title);
    await page.getByRole("button", { name: "Add" }).click();

    // Open row: <Card><div><p>title</p>...</div><div>Done/Dismiss</div></Card>
    // -- two levels up from the title text reaches the Card.
    const openRow = page.getByText(title, { exact: true }).locator("..").locator("..");
    await expect(page.getByText(title, { exact: true })).toBeVisible();

    await openRow.getByRole("button", { name: "Done" }).click();
    await expect(page.getByText(title, { exact: true })).not.toBeVisible();

    // Recently done row: <div><p className="line-through">title</p><form>Reopen</form></div>
    // -- one level up from the title text reaches the row, scoping which
    // Reopen button to click (the QA account may carry other done items
    // from earlier runs).
    const doneRow = page.getByText(title, { exact: true }).locator("..");
    await doneRow.getByRole("button", { name: "Reopen" }).click();
    await expect(page.getByText(title, { exact: true })).toBeVisible();

    const reopenedRow = page.getByText(title, { exact: true }).locator("..").locator("..");
    await reopenedRow.getByRole("button", { name: "Dismiss" }).click();
    await expect(page.getByText(title, { exact: true })).not.toBeVisible();
  });
});
