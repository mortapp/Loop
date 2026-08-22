import type { ButtonHTMLAttributes } from "react";

type ButtonVariant = "primary" | "secondary" | "ghost" | "danger";

const base =
  "inline-flex items-center justify-center gap-2 rounded-[var(--radius-sm)] px-4 py-2 text-sm font-medium transition-colors disabled:opacity-50 disabled:pointer-events-none focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-offset-2 focus-visible:ring-[var(--color-border-strong)]";

const variants: Record<ButtonVariant, string> = {
  primary:
    "bg-[var(--color-brand)] text-[var(--color-on-accent)] hover:bg-[var(--color-brand-hover)] active:bg-[var(--color-brand-pressed)]",
  secondary:
    "bg-[var(--color-surface)] text-[var(--color-text-primary)] border border-[var(--color-border-strong)] hover:bg-[var(--color-surface-hover)]",
  ghost:
    "text-[var(--color-text-secondary)] hover:text-[var(--color-text-primary)] hover:bg-[var(--color-surface-hover)]",
  danger:
    "bg-[var(--color-danger)] text-[var(--color-on-accent)] hover:opacity-90",
};

/**
 * The one button implementation for LOOP web — replaces every one-off
 * `<button className="rounded-lg border...">` scattered across pages.
 * `loading` disables the button and shows a spinner without changing its
 * size (avoids layout shift), matching Part 17's "a primary action should
 * never feel dead after being clicked."
 */
export function Button({
  variant = "primary",
  loading = false,
  className = "",
  children,
  disabled,
  ...props
}: ButtonHTMLAttributes<HTMLButtonElement> & {
  variant?: ButtonVariant;
  loading?: boolean;
}) {
  return (
    <button
      className={`${base} ${variants[variant]} ${className}`}
      disabled={disabled || loading}
      aria-busy={loading || undefined}
      {...props}
    >
      {loading ? (
        <span
          className="h-3.5 w-3.5 animate-spin rounded-full border-2 border-current border-t-transparent"
          aria-hidden="true"
        />
      ) : null}
      {children}
    </button>
  );
}
