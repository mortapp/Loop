"use server";

import { revalidatePath } from "next/cache";
import { setThemePreference, type ThemePreference } from "@/lib/theme";

export async function setTheme(theme: ThemePreference) {
  await setThemePreference(theme);
  revalidatePath("/", "layout");
}
