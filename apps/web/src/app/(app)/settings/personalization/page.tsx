import Link from "next/link";
import { getThemePreference } from "@/lib/theme";
import { ThemePicker } from "./theme-picker";

export default async function PersonalizationPage() {
  const theme = await getThemePreference();

  return (
    <div className="flex flex-col gap-6">
      <div>
        <Link href="/settings" className="text-xs text-[var(--color-text-tertiary)] hover:underline">
          ← Settings
        </Link>
        <h1 className="mt-1 text-xl font-semibold text-[var(--color-text-primary)]">Personalization</h1>
      </div>

      <div className="flex flex-col gap-2">
        <h2 className="text-xs font-semibold tracking-[0.1em] text-[var(--color-text-secondary)]">
          THEME
        </h2>
        <ThemePicker current={theme} />
      </div>
    </div>
  );
}
