import type { ReactNode } from "react";

export function LedgerPageIntro({
  title,
  subtitle,
  trailing,
}: {
  title: string;
  subtitle?: string;
  trailing?: ReactNode;
}) {
  return (
    <div className="flex items-end justify-between gap-4">
      <div>
        <h1
          className="text-3xl text-[var(--color-text-primary)]"
          style={{ fontFamily: "var(--font-display)", fontWeight: 600 }}
        >
          {title}
        </h1>
        {subtitle ? (
          <p className="mt-1 text-sm text-[var(--color-text-secondary)]">{subtitle}</p>
        ) : null}
      </div>
      {trailing}
    </div>
  );
}

export function LedgerSectionLabel({
  children,
  trailing,
}: {
  children: ReactNode;
  trailing?: ReactNode;
}) {
  return (
    <div className="flex items-center justify-between gap-4">
      <h2 className="text-[11px] font-semibold uppercase tracking-[0.12em] text-[var(--color-text-tertiary)]">
        {children}
      </h2>
      {trailing}
    </div>
  );
}

export function LedgerHero({
  eyebrow,
  value,
  detail,
  action,
}: {
  eyebrow: string;
  value: ReactNode;
  detail?: ReactNode;
  action?: ReactNode;
}) {
  return (
    <section className="border-y border-[var(--color-border-subtle)] py-6">
      <p className="text-[11px] font-semibold uppercase tracking-[0.12em] text-[var(--color-text-tertiary)]">
        {eyebrow}
      </p>
      <div className="mt-2">{value}</div>
      {detail ? (
        <div className="mt-1 text-sm text-[var(--color-text-secondary)]">{detail}</div>
      ) : null}
      {action ? <div className="mt-4">{action}</div> : null}
    </section>
  );
}

export function LedgerRow({
  children,
  className = "",
}: {
  children: ReactNode;
  className?: string;
}) {
  return (
    <div
      className={`flex min-h-14 items-center justify-between gap-4 border-b border-[var(--color-border-subtle)] py-3 ${className}`}
    >
      {children}
    </div>
  );
}
