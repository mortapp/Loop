import { test, expect } from "@playwright/test";
import { hasQaCredentials } from "../playwright.config";

/**
 * ANTHROPIC_API_KEY is OWNER_ACTION_REQUIRED (see docs/KNOWN_ISSUES.md) --
 * this test asserts the page renders correctly in whichever state is
 * actually configured, rather than assuming one.
 */
test.describe("AI", () => {
  test.beforeEach(() => {
    test.skip(!hasQaCredentials, "requires QA_TEST_EMAIL/QA_TEST_PASSWORD");
  });

  test("renders the Ask LOOP page in its current configuration state", async ({ page }) => {
    await page.goto("/ai");
    await expect(page.getByRole("heading", { name: /ask loop/i })).toBeVisible();

    const chatInput = page.getByPlaceholder(/ask|message/i);
    const notConfiguredNotice = page.getByText(/ANTHROPIC_API_KEY/);

    await expect(chatInput.or(notConfiguredNotice).first()).toBeVisible();
  });
});
