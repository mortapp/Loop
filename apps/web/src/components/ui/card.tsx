import type { HTMLAttributes } from "react";

/**
 * The one surface container for LOOP — replaces repeated
 * `rounded-2xl border bg-white dark:border-zinc-800 dark:bg-zinc-950`
 * literals across every page. `interactive` adds a hover state for cards
 * that are themselves a link/button target.
 */
export function Card({
  interactive = false,
  className = "",
  children,
  ...props
}: HTMLAttributes<HTMLDivElement> & { interactive?: boolean }) {
  return (
    <div
      className={`rounded-[var(--radius-md)] border border-[var(--color-border-subtle)] bg-[var(--color-surface)] ${
        interactive ? "transition-colors hover:bg-[var(--color-surface-hover)]" : ""
      } ${className}`}
      {...props}
    >
      {children}
    </div>
  );
}
