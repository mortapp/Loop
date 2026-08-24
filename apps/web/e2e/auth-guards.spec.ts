import { test, expect } from "@playwright/test";

/**
 * Unauthenticated access must never reach an app page -- both gates
 * (src/proxy.ts for (app)/**, and the root page's own redirect) route to
 * /sign-in. These run with no storage state and no QA credentials, so
 * they always execute in CI, independent of Phase 4's OWNER_ACTION_
 * REQUIRED QA account gate.
 */
test.describe("auth guards (unauthenticated)", () => {
  test.use({ storageState: { cookies: [], origins: [] } });

  for (const path of [
    "/today",
    "/money",
    "/money/purchases",
    "/sell",
    "/business",
    "/business/contacts",
    "/business/leads",
    "/business/opportunities",
    "/business/quotes",
    "/ai",
    "/profile",
    "/settings",
    "/settings/personalization",
    "/help",
  ]) {
    test(`${path} redirects to /sign-in`, async ({ page }) => {
      await page.goto(path);
      await expect(page).toHaveURL(/\/sign-in/);
    });
  }

  test("/ redirects to /sign-in", async ({ page }) => {
    await page.goto("/");
    await expect(page).toHaveURL(/\/sign-in/);
  });

  test("/sign-in and /sign-up render without requiring auth", async ({ page }) => {
    await page.goto("/sign-in");
    await expect(page.getByRole("button", { name: /^sign in$/i })).toBeVisible();

    await page.goto("/sign-up");
    await expect(page.getByRole("button", { name: /^sign up$/i })).toBeVisible();
  });

  for (const path of ["/api/ai/chat", "/api/ai/confirm"]) {
    test(`${path} reaches its bearer-token auth boundary`, async ({ request }) => {
      const response = await request.post(path, {
        data: {
          messages: [{ role: "user", content: "Synthetic auth-boundary check" }],
          accountId: "00000000-0000-0000-0000-000000000000",
        },
        maxRedirects: 0,
      });

      expect(response.status()).not.toBe(307);
      expect(response.headers().location ?? "").not.toContain("/sign-in");
      expect(response.headers()["content-type"] ?? "").toContain("application/json");
    });
  }
});
