import { test, expect } from "@playwright/test";
import { hasQaCredentials } from "../playwright.config";

/**
 * Responsive QA across the breakpoint set from the design directive
 * (360/390/430/768/1024/1280/1440). The Chrome extension's
 * `resize_window` tool is unreliable against this app's authenticated
 * shell (silently no-ops -- see docs/KNOWN_ISSUES.md history); Playwright's
 * real `setViewportSize` is the alternative -- it actually resizes the
 * page before each navigation, not after, so layout is correct from the
 * first paint.
 *
 * The core check is "no horizontal overflow": `<body>` must never be
 * wider than the viewport at any of these widths. A few px of tolerance
 * covers scrollbar-width rounding differences between platforms.
 */
const BREAKPOINTS = [360, 390, 430, 768, 1024, 1280, 1440] as const;
const OVERFLOW_TOLERANCE_PX = 2;

async function assertNoHorizontalOverflow(page: import("@playwright/test").Page, width: number) {
  const overflow = await page.evaluate(() => document.documentElement.scrollWidth - window.innerWidth);
  expect(overflow, `horizontal overflow at ${width}px viewport`).toBeLessThanOrEqual(OVERFLOW_TOLERANCE_PX);
}

test.describe("responsive (public pages, no auth needed)", () => {
  test.use({ storageState: { cookies: [], origins: [] } });

  for (const width of BREAKPOINTS) {
    test(`/sign-in has no horizontal overflow at ${width}px`, async ({ page }) => {
      await page.setViewportSize({ width, height: 900 });
      await page.goto("/sign-in");
      await expect(page.getByRole("button", { name: /^sign in$/i })).toBeVisible();
      await assertNoHorizontalOverflow(page, width);
    });
  }
});

test.describe("responsive (authenticated pages)", () => {
  test.beforeEach(() => {
    test.skip(!hasQaCredentials, "requires QA_TEST_EMAIL/QA_TEST_PASSWORD");
  });

  const authedPages = ["/today", "/money", "/sell", "/business", "/ai"] as const;

  for (const width of BREAKPOINTS) {
    for (const path of authedPages) {
      test(`${path} has no horizontal overflow at ${width}px`, async ({ page }) => {
        await page.setViewportSize({ width, height: 900 });
        await page.goto(path);
        await assertNoHorizontalOverflow(page, width);
      });
    }
  }

  test("the primary nav switches from bottom tab bar (< md) to a side rail (>= md)", async ({ page }) => {
    await page.setViewportSize({ width: 390, height: 900 });
    await page.goto("/today");
    const navs = page.getByRole("navigation", { name: "Primary" });
    // Below md: the bottom tab bar is the only one actually visible.
    await expect(navs.first()).toBeVisible();

    await page.setViewportSize({ width: 1280, height: 900 });
    await page.reload();
    await expect(page.getByRole("navigation", { name: "Primary" }).first()).toBeVisible();
    // At lg+, the rail shows full labels (hidden entirely below md).
    await expect(page.getByText("LOOP", { exact: true })).toBeVisible();
  });
});
