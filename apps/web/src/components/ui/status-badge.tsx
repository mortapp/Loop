type StatusTone = "neutral" | "brand" | "info" | "opportunity" | "danger" | "warning";

const toneClasses: Record<StatusTone, string> = {
  neutral: "bg-[var(--color-bg-secondary)] text-[var(--color-text-secondary)]",
  brand: "bg-[var(--color-brand-soft)] text-[var(--color-brand-text)]",
  info: "bg-[var(--color-info-soft)] text-[var(--color-info-text)]",
  opportunity: "bg-[var(--color-opportunity-soft)] text-[var(--color-opportunity-text)]",
  danger: "bg-[var(--color-danger-soft)] text-[var(--color-danger-text)]",
  warning: "bg-[var(--color-warning-soft)] text-[var(--color-warning-text)]",
};

/**
 * Status is always communicated via color + text together, never color
 * alone (Part 23 — colorblind users, and anyone on a washed-out screen,
 * still need to read the state). Each domain page maps its own enum
 * (lead_status, quote_status, return_status, ...) to a tone rather than
 * this component knowing about every possible status string in the app.
 */
export function StatusBadge({ label, tone = "neutral" }: { label: string; tone?: StatusTone }) {
  return (
    <span
      className={`inline-flex items-center rounded-full px-2.5 py-0.5 text-xs font-medium ${toneClasses[tone]}`}
    >
      {label}
    </span>
  );
}
