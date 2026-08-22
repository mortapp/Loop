import type { ReactNode } from "react";

/**
 * One first-class empty state instead of ad hoc "No X yet" paragraphs
 * per page (Part 24 of the design brief). Simple explanation + one
 * primary action — not a giant illustration, not a depressing blank
 * screen.
 */
export function EmptyState({
  title,
  description,
  action,
}: {
  title: string;
  description?: string;
  action?: ReactNode;
}) {
  return (
    <div className="flex flex-col items-start gap-2 rounded-[var(--radius-md)] border border-dashed border-[var(--color-border-subtle)] px-4 py-6">
      <p className="text-sm font-medium text-[var(--color-text-primary)]">{title}</p>
      {description ? (
        <p className="text-sm text-[var(--color-text-secondary)]">{description}</p>
      ) : null}
      {action ? <div className="mt-1">{action}</div> : null}
    </div>
  );
}
