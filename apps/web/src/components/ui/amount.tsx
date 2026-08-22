import { formatCents } from "@/lib/format";

type AmountTone = "neutral" | "auto" | "brand" | "danger" | "opportunity";

/**
 * Every monetary value in LOOP renders through this, never a bare
 * `{cents / 100}`. Uses Geist Mono's real tabular figures so a column of
 * amounts actually lines up, and only applies sign-aware color when asked
 * for — a quote total isn't inherently "positive," but a Money ledger net
 * figure is.
 */
export function Amount({
  cents,
  currency = "USD",
  tone = "neutral",
  size = "md",
  signed = false,
  className = "",
}: {
  cents: number | null | undefined;
  currency?: string;
  tone?: AmountTone;
  size?: "sm" | "md" | "lg";
  /** Show an explicit +/- sign — for ledger-style entries where the
      direction of money movement is the point, not just its magnitude. */
  signed?: boolean;
  className?: string;
}) {
  const resolvedTone: Exclude<AmountTone, "auto"> =
    tone === "auto" ? (cents === null || cents === undefined || cents === 0 ? "neutral" : cents > 0 ? "brand" : "danger") : tone;

  const toneClass = {
    neutral: "text-[var(--color-text-primary)]",
    brand: "text-[var(--color-brand-text)]",
    danger: "text-[var(--color-danger-text)]",
    opportunity: "text-[var(--color-opportunity-text)]",
  }[resolvedTone];

  const sizeClass = {
    sm: "text-sm",
    md: "text-base",
    lg: "text-2xl",
  }[size];

  return (
    <span className={`tabular-nums-mono ${toneClass} ${sizeClass} ${className}`}>
      {formatCents(cents, currency, { signDisplay: signed })}
    </span>
  );
}
