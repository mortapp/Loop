"use client";

import { useTransition } from "react";
import type { ThemePreference } from "@/lib/theme";
import { setTheme } from "./actions";

const OPTIONS: { value: ThemePreference; label: string; description: string }[] = [
  { value: "system", label: "System", description: "Follows your device's setting." },
  { value: "dark", label: "Dark", description: "Murex Noir, always." },
  { value: "light", label: "Light", description: "Royal Bone, always." },
];

export function ThemePicker({ current }: { current: ThemePreference }) {
  const [pending, startTransition] = useTransition();

  return (
    <div role="radiogroup" aria-label="Theme" className="flex flex-col gap-2">
      {OPTIONS.map((option) => {
        const selected = option.value === current;
        return (
          <button
            key={option.value}
            type="button"
            role="radio"
            aria-checked={selected}
            disabled={pending}
            onClick={() => startTransition(() => setTheme(option.value))}
            className={`flex items-center justify-between rounded-[var(--radius-md)] border px-4 py-3 text-left transition-colors disabled:opacity-60 ${
              selected
                ? "border-[var(--color-brand)] bg-[var(--color-surface)]"
                : "border-[var(--color-border-subtle)] bg-[var(--color-surface)] hover:bg-[var(--color-surface-hover)]"
            }`}
          >
            <div>
              <p className="text-sm font-medium text-[var(--color-text-primary)]">{option.label}</p>
              <p className="text-xs text-[var(--color-text-tertiary)]">{option.description}</p>
            </div>
            {selected ? (
              <span aria-hidden className="text-[var(--color-brand-text)]">
                ✓
              </span>
            ) : null}
          </button>
        );
      })}
    </div>
  );
}
