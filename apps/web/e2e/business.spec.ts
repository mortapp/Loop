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
      ["People", "/business/contacts"],
      ["Leads", "/business/leads"],
      ["Work", "/business/opportunities"],
      ["Quotes", "/business/quotes"],
    ] as const) {
      await page.goto("/business");
      if (label === "Leads") {
        await page.getByRole("link", { name: /Leads/ }).click();
      } else {
        const sectionHeader = page.getByRole("heading", { name: label }).locator("..");
        await sectionHeader.getByRole("link", { name: "See all" }).click();
      }
      await expect(page).toHaveURL(new RegExp(`${path}$`));
      const destinationHeading =
        label === "People" ? "Contacts" : label === "Work" ? "Opportunities" : label;
      await expect(page.getByRole("heading", { name: destinationHeading })).toBeVisible();
    }
  });
});
