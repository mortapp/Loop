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
    description: "The next thing that needs your attention.",
  },
  {
    href: "/money",
    label: "Money",
    description: "Everything made, protected, and recovered.",
  },
  {
    href: "/sell",
    label: "Sell",
    description: "Inventory you can turn back into value.",
  },
  {
    href: "/business",
    label: "Business",
    description: "People, work, and quotes in one place.",
  },
  {
    href: "/ai",
    label: "Ask LOOP",
    description: "Private counsel for your value in motion.",
  },
] as const;

export type NavItem = (typeof NAV_ITEMS)[number];
