"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { NAV_ITEMS } from "@/lib/nav";
import { NAV_ICONS } from "@/lib/nav-icons";
import { LoopSeal } from "@/components/ui/loop-seal";

/**
 * The authenticated app shell — a compact vertical rail on desktop/tablet,
 * a top bar + bottom tab bar on mobile web. Replaces the old horizontal
 * pill nav, which read as a generic SaaS header no matter what tokens it
 * used. Deliberately not a wide SaaS sidebar: the rail is icon-only at
 * md, gains labels at lg, and never exceeds ~13rem.
 */
export function AppShell({
  activeAccountLabel,
  signOutAction,
  children,
}: {
  activeAccountLabel: string | null;
  signOutAction: () => Promise<void>;
  children: React.ReactNode;
}) {
  const pathname = usePathname();
  const isActive = (href: string) => pathname === href || pathname.startsWith(`${href}/`);

  return (
    <div className="min-h-full bg-[var(--color-bg)]">
      {/* Desktop / tablet rail — md: icon-only, lg: full width with labels */}
      <aside className="fixed inset-y-0 left-0 z-20 hidden w-16 flex-col border-r border-[var(--color-border-subtle)] bg-[var(--color-bg)] md:flex lg:w-52">
        <div className="flex flex-col items-center gap-1 px-3 py-5 lg:items-start">
          <Link href="/today" className="flex items-center gap-2">
            <LoopSeal size={26} />
            <span
              className="hidden text-lg tracking-[0.15em] text-[var(--color-text-primary)] lg:inline"
              style={{ fontFamily: "var(--font-display)", fontWeight: 600 }}
            >
              LOOP
            </span>
          </Link>
          {activeAccountLabel ? (
            <Link
              href="/business"
              title={`Switch account — currently ${activeAccountLabel}`}
              className="mt-3 w-full truncate rounded-[var(--radius-sm)] bg-[var(--color-surface)] px-2 py-1.5 text-center text-xs font-medium text-[var(--color-text-secondary)] transition-colors hover:bg-[var(--color-surface-hover)] lg:text-left"
            >
              <span className="lg:hidden">{activeAccountLabel.slice(0, 1).toUpperCase()}</span>
              <span className="hidden lg:inline">{activeAccountLabel}</span>
            </Link>
          ) : null}
        </div>

        <nav className="flex flex-1 flex-col gap-0.5 px-2" aria-label="Primary">
          {NAV_ITEMS.map((item) => {
            const active = isActive(item.href);
            const Icon = NAV_ICONS[item.href];
            return (
              <Link
                key={item.href}
                href={item.href}
                aria-current={active ? "page" : undefined}
                className={`relative flex items-center gap-3 rounded-[var(--radius-sm)] px-2.5 py-2.5 text-sm font-medium transition-colors lg:px-3 ${
                  active
                    ? "text-[var(--color-text-primary)]"
                    : "text-[var(--color-text-tertiary)] hover:text-[var(--color-text-secondary)]"
                }`}
              >
                {active ? (
                  <span
                    aria-hidden
                    className="absolute -left-2 top-1/2 h-4 w-[2px] -translate-y-1/2 rounded-full bg-[var(--color-brand-accent)] lg:-left-2"
                  />
                ) : null}
                <Icon active={active} />
                <span className="hidden lg:inline">{item.label}</span>
              </Link>
            );
          })}
        </nav>

        <div className="border-t border-[var(--color-border-subtle)] px-2 py-3">
          <form action={signOutAction}>
            <button
              type="submit"
              className="w-full rounded-[var(--radius-sm)] px-2.5 py-2 text-center text-xs text-[var(--color-text-tertiary)] transition-colors hover:text-[var(--color-text-primary)] lg:text-left"
            >
              <span className="lg:hidden" aria-hidden>
                ⏻
              </span>
              <span className="hidden lg:inline">Sign out</span>
            </button>
          </form>
        </div>
      </aside>

      {/* Mobile web top bar */}
      <header className="flex items-center justify-between border-b border-[var(--color-border-subtle)] bg-[var(--color-bg-secondary)] px-4 py-3 md:hidden">
        <Link href="/today" className="flex items-center gap-2">
          <LoopSeal size={24} />
          <span
            className="text-base tracking-[0.15em] text-[var(--color-text-primary)]"
            style={{ fontFamily: "var(--font-display)", fontWeight: 600 }}
          >
            LOOP
          </span>
        </Link>
        <div className="flex items-center gap-3">
          {activeAccountLabel ? (
            <Link
              href="/business"
              className="rounded-full bg-[var(--color-surface)] px-2.5 py-1 text-xs font-medium text-[var(--color-text-secondary)]"
            >
              {activeAccountLabel}
            </Link>
          ) : null}
          <form action={signOutAction}>
            <button
              type="submit"
              className="text-sm text-[var(--color-text-tertiary)] transition-colors hover:text-[var(--color-text-primary)]"
            >
              Sign out
            </button>
          </form>
        </div>
      </header>

      {/* Mobile web bottom tab bar — same five items/order as apps/mobile */}
      <nav
        aria-label="Primary"
        className="fixed inset-x-0 bottom-0 z-20 flex border-t border-[var(--color-border-subtle)] bg-[var(--color-bg)] pb-[env(safe-area-inset-bottom)] md:hidden"
      >
        {NAV_ITEMS.map((item) => {
          const active = isActive(item.href);
          const Icon = NAV_ICONS[item.href];
          return (
            <Link
              key={item.href}
              href={item.href}
              aria-current={active ? "page" : undefined}
              className={`flex flex-1 flex-col items-center gap-1 py-2.5 text-[10px] font-medium ${
                active ? "text-[var(--color-text-primary)]" : "text-[var(--color-text-tertiary)]"
              }`}
            >
              <Icon active={active} />
              {item.label}
            </Link>
          );
        })}
      </nav>

      <main className="min-h-full px-4 pb-20 pt-6 md:ml-16 md:px-6 md:pb-8 lg:ml-52">
        <div className="mx-auto w-full max-w-4xl">{children}</div>
      </main>
    </div>
  );
}
