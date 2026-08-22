import { LoopSeal } from "@/components/ui/loop-seal";

/**
 * Minimal stroke icons for the five primary nav items — deliberately
 * plain geometry (no icon library dependency, no filled/decorative
 * glyphs) so they read as restrained wayfinding, not illustration.
 * `currentColor` throughout so active/inactive state is just a text
 * color change, same as the label next to it.
 */
const common = {
  width: 18,
  height: 18,
  viewBox: "0 0 18 18",
  fill: "none",
  stroke: "currentColor",
  strokeWidth: 1.4,
  strokeLinecap: "round" as const,
  strokeLinejoin: "round" as const,
  "aria-hidden": true,
};

export function TodayIcon() {
  return (
    <svg {...common}>
      <rect x="2.5" y="2.5" width="13" height="13" rx="2" />
      <path d="M5.5 7h7M5.5 10.2h4.5" />
    </svg>
  );
}

export function MoneyIcon() {
  return (
    <svg {...common}>
      <rect x="2" y="4.5" width="14" height="9" rx="1.6" />
      <circle cx="9" cy="9" r="2.1" />
      <path d="M2 7.2h1.4M16 10.8h-1.4" />
    </svg>
  );
}

export function SellIcon() {
  return (
    <svg {...common}>
      <path d="M9 2.5l6.2 6.2a1.6 1.6 0 0 1 0 2.26L11.4 14.7a1.6 1.6 0 0 1-2.26 0L2.9 8.5V2.5H9z" />
      <circle cx="6.1" cy="5.7" r="0.9" fill="currentColor" stroke="none" />
    </svg>
  );
}

export function BusinessIcon() {
  return (
    <svg {...common}>
      <path d="M3.5 15.5V4.8L9 2.5l5.5 2.3v10.7" />
      <path d="M3.5 15.5h11M7 15.5V9h4v6.5" />
    </svg>
  );
}

export function AiIcon({ active }: { active?: boolean }) {
  return <LoopSeal size={20} className={active ? "opacity-100" : "opacity-70"} />;
}

/** Keyed by NAV_ITEMS[].href (lib/nav.ts) — kept out of that file so it
 * stays JSX-free and safely importable from non-component contexts. */
export const NAV_ICONS: Record<string, (props: { active?: boolean }) => React.JSX.Element> = {
  "/today": TodayIcon,
  "/money": MoneyIcon,
  "/sell": SellIcon,
  "/business": BusinessIcon,
  "/ai": AiIcon,
};
