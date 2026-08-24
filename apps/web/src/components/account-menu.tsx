"use client";

import { useEffect, useId, useRef, useState } from "react";
import Link from "next/link";

type AccountMenuProps = {
  displayName: string | null;
  email: string;
  initials: string;
  activeAccountLabel: string | null;
  signOutAction: () => Promise<void>;
  /** "rail" = desktop vertical rail (menu opens upward, avatar+name
   *  visible at lg); "mobile" = the mobile-web top bar (icon only,
   *  menu opens downward as a compact sheet-like panel). */
  variant?: "rail" | "mobile";
};

/**
 * The account identity control — avatar + name opens a menu with
 * Account / Profile / Appearance / Help / Sign out. Deliberately no
 * billing/plan/upgrade rows: LOOP has no
 * subscription tiers, so those would be dead UI copied from a ChatGPT-
 * style reference rather than earned by a real product need.
 *
 * Real keyboard/focus handling, not a native <details> (which doesn't
 * close on Escape or outside click in most browsers): click-outside and
 * Escape both close the menu, and closing returns focus to the trigger.
 */
export function AccountMenu({
  displayName,
  email,
  initials,
  activeAccountLabel,
  signOutAction,
  variant = "rail",
}: AccountMenuProps) {
  const [open, setOpen] = useState(false);
  const containerRef = useRef<HTMLDivElement>(null);
  const triggerRef = useRef<HTMLButtonElement>(null);
  const firstItemRef = useRef<HTMLAnchorElement>(null);

  useEffect(() => {
    if (!open) return;

    function handlePointerDown(e: PointerEvent) {
      if (containerRef.current && !containerRef.current.contains(e.target as Node)) {
        setOpen(false);
      }
    }
    function handleKeyDown(e: KeyboardEvent) {
      if (e.key === "Escape") {
        setOpen(false);
        triggerRef.current?.focus();
      }
    }
    document.addEventListener("pointerdown", handlePointerDown);
    document.addEventListener("keydown", handleKeyDown);
    firstItemRef.current?.focus();
    return () => {
      document.removeEventListener("pointerdown", handlePointerDown);
      document.removeEventListener("keydown", handleKeyDown);
    };
  }, [open]);

  // Two AccountMenu instances render at once (the desktop rail + the
  // mobile-web header, each hidden via CSS at the other's breakpoint) --
  // useId keeps their menu ids from colliding in the DOM even though
  // only one is ever open at a time.
  const menuId = useId();

  return (
    <div ref={containerRef} className="relative">
      <button
        ref={triggerRef}
        type="button"
        aria-haspopup="menu"
        aria-expanded={open}
        aria-controls={menuId}
        aria-label={`Account menu for ${displayName || email}`}
        onClick={() => setOpen((v) => !v)}
        className={
          variant === "rail"
            ? "flex w-full items-center gap-2 rounded-[var(--radius-sm)] px-2.5 py-2 text-left transition-colors hover:bg-[var(--color-surface-hover)]"
            : "flex items-center justify-center rounded-full transition-opacity hover:opacity-80"
        }
      >
        <span
          aria-hidden
          className="flex h-7 w-7 shrink-0 items-center justify-center rounded-full bg-[var(--color-brand)] text-[10px] font-semibold text-[var(--color-on-accent)]"
        >
          {initials}
        </span>
        {variant === "rail" ? (
          <span className="hidden min-w-0 flex-1 lg:block">
            <span className="block truncate text-xs font-medium text-[var(--color-text-primary)]">
              {displayName || email}
            </span>
            <span className="block truncate text-[10px] text-[var(--color-text-tertiary)]">
              {activeAccountLabel ?? "Personal"}
            </span>
          </span>
        ) : null}
      </button>

      {open ? (
        <div
          id={menuId}
          role="menu"
          aria-label="Account menu"
          className={
            "absolute z-30 w-56 rounded-[var(--radius-md)] border border-[var(--color-border-subtle)] bg-[var(--color-surface)] p-1.5 shadow-lg " +
            (variant === "rail" ? "bottom-full left-0 mb-2" : "right-0 top-full mt-2")
          }
        >
          <div className="border-b border-[var(--color-border-subtle)] px-2.5 py-2">
            <p className="truncate text-xs font-medium text-[var(--color-text-primary)]">
              {displayName || "Your account"}
            </p>
            <p className="truncate text-[11px] text-[var(--color-text-tertiary)]">{email}</p>
          </div>

          <div className="py-1">
            <MenuLink ref={firstItemRef} href="/settings" onSelect={() => setOpen(false)}>
              Account
            </MenuLink>
            <MenuLink href="/profile" onSelect={() => setOpen(false)}>
              Profile
            </MenuLink>
            <MenuLink href="/settings/personalization" onSelect={() => setOpen(false)}>
              Appearance
            </MenuLink>
            <MenuLink href="/help" onSelect={() => setOpen(false)}>
              Help
            </MenuLink>
          </div>

          <div className="border-t border-[var(--color-border-subtle)] pt-1">
            <form action={signOutAction}>
              <button
                type="submit"
                role="menuitem"
                className="block w-full rounded-[var(--radius-sm)] px-2.5 py-1.5 text-left text-xs text-[var(--color-text-secondary)] transition-colors hover:bg-[var(--color-surface-hover)] hover:text-[var(--color-text-primary)]"
              >
                Sign out
              </button>
            </form>
          </div>
        </div>
      ) : null}
    </div>
  );
}

function MenuLink({
  href,
  onSelect,
  children,
  ref,
}: {
  href: string;
  onSelect: () => void;
  children: React.ReactNode;
  ref?: React.Ref<HTMLAnchorElement>;
}) {
  return (
    <Link
      ref={ref}
      href={href}
      role="menuitem"
      onClick={onSelect}
      className="block rounded-[var(--radius-sm)] px-2.5 py-1.5 text-xs text-[var(--color-text-secondary)] transition-colors hover:bg-[var(--color-surface-hover)] hover:text-[var(--color-text-primary)]"
    >
      {children}
    </Link>
  );
}
