import { cookies } from "next/headers";

/**
 * Personalization → theme: System (default, follows the OS) / Dark /
 * Light. Persisted as a cookie so the server-rendered <html> tag can set
 * data-theme before first paint (no flash-of-wrong-theme) — same pattern
 * as active-account.ts's account cookie.
 */
export type ThemePreference = "system" | "dark" | "light";

const THEME_COOKIE = "loop_theme";

export async function getThemePreference(): Promise<ThemePreference> {
  const cookieStore = await cookies();
  const value = cookieStore.get(THEME_COOKIE)?.value;
  return value === "dark" || value === "light" ? value : "system";
}

export async function setThemePreference(theme: ThemePreference): Promise<void> {
  const cookieStore = await cookies();
  if (theme === "system") {
    cookieStore.delete(THEME_COOKIE);
    return;
  }
  cookieStore.set(THEME_COOKIE, theme, {
    path: "/",
    maxAge: 60 * 60 * 24 * 365,
    sameSite: "lax",
  });
}
