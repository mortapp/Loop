import { test, expect } from "@playwright/test";
import { hasQaCredentials } from "../playwright.config";

test.describe("Business", () => {
  test.beforeEach(() => {
    test.skip(!hasQaCredentials, "requires QA_TEST_EMAIL/QA_TEST_PASSWORD");
  });

  test("the active account is shown and the hub links reach real pages", async ({ page }) => {
    await page.goto("/business");
    await expect(page.getByText("Active").first()).toBeVisible();

    for (const [label, path] of [
      ["Contacts", "/business/contacts"],
      ["Leads", "/business/leads"],
      ["Opportunities", "/business/opportunities"],
      ["Quotes", "/business/quotes"],
    ] as const) {
      await page.goto("/business");
      await page.getByRole("link", { name: new RegExp(label) }).click();
      await expect(page).toHaveURL(new RegExp(`${path}$`));
      await expect(page.getByRole("heading", { name: label })).toBeVisible();
    }
  });
});
