/**
 * The five primary product areas (CLAUDE.md), shared between the web nav
 * shell and (eventually) any place that needs to render/link to them.
 * Keep this in sync with apps/mobile's bottom nav — same five tabs, same
 * order — so the product feels like one system across platforms.
 */
export const NAV_ITEMS = [
  {
    href: "/today",
    label: "Today",
    description: "Your unified queue of actions across everything LOOP tracks.",
  },
  {
    href: "/money",
    label: "Money",
    description: "Everything earned, spent, refunded, and recovered.",
  },
  {
    href: "/sell",
    label: "Sell",
    description: "RECOVER / ResellLens — turn owned items back into cash.",
  },
  {
    href: "/business",
    label: "Business",
    description: "Switch between your personal account and businesses you belong to.",
  },
  {
    href: "/ai",
    label: "AI",
    description: "Ask LOOP to take safe, confirmed actions on your behalf.",
  },
] as const;

export type NavItem = (typeof NAV_ITEMS)[number];
