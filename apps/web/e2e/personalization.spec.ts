import { test, expect } from "@playwright/test";
import { hasQaCredentials } from "../playwright.config";

test.describe("Personalization", () => {
  test.beforeEach(() => {
    test.skip(!hasQaCredentials, "requires QA_TEST_EMAIL/QA_TEST_PASSWORD");
  });

  test("choosing a theme persists across reload", async ({ page }) => {
    await page.goto("/settings/personalization");
    const group = page.getByRole("radiogroup", { name: "Theme" });

    // Start from a known state, then flip it, so the test is meaningful
    // regardless of what a previous run left selected.
    await group.getByRole("radio", { name: "Dark" }).click();
    await expect(group.getByRole("radio", { name: "Dark" })).toHaveAttribute("aria-checked", "true");

    await group.getByRole("radio", { name: "Light" }).click();
    await expect(group.getByRole("radio", { name: "Light" })).toHaveAttribute("aria-checked", "true");

    await page.reload();
    await expect(page.getByRole("radiogroup", { name: "Theme" }).getByRole("radio", { name: "Light" })).toHaveAttribute(
      "aria-checked",
      "true",
    );

    // Leave it back on System so the QA account doesn't drift into a
    // fixed theme for whatever runs next.
    await page.getByRole("radiogroup", { name: "Theme" }).getByRole("radio", { name: "System" }).click();
  });
});
