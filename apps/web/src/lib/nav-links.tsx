"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { NAV_ITEMS } from "./nav";

/**
 * Client Component isolated to just the nav row so it can read the
 * current pathname (usePathname is client-only) — everything else in the
 * app shell stays a Server Component. Previously every nav link looked
 * identical regardless of the current route; a real product needs to
 * show you where you are.
 */
export function NavLinks() {
  const pathname = usePathname();

  return (
    <nav className="mx-auto flex w-full max-w-5xl gap-1 overflow-x-auto px-4 pb-2">
      {NAV_ITEMS.map((item) => {
        const active = pathname === item.href || pathname.startsWith(`${item.href}/`);
        return (
          <Link
            key={item.href}
            href={item.href}
            aria-current={active ? "page" : undefined}
            className={`rounded-full px-3 py-1.5 text-sm font-medium whitespace-nowrap transition-colors ${
              active
                ? "bg-[var(--color-brand-soft)] text-[var(--color-brand-text)]"
                : "text-[var(--color-text-secondary)] hover:bg-[var(--color-surface-hover)] hover:text-[var(--color-text-primary)]"
            }`}
          >
            {item.label}
          </Link>
        );
      })}
    </nav>
  );
}
