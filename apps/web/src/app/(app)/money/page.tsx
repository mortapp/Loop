import Link from "next/link";
import type { MoneyEvent, MoneyEventKind } from "@loop/contracts";
import { createClient } from "@/lib/supabase/server";
import { getActiveAccountId } from "@/lib/active-account";
import { formatCents } from "@/lib/format";
import { Amount } from "@/components/ui/amount";
import { EmptyState } from "@/components/ui/empty-state";
import { LedgerHero, LedgerPageIntro, LedgerRow, LedgerSectionLabel } from "@/components/ui/ledger";
import { LogEventForm } from "./log-event-form";

const KIND_SIGN: Record<MoneyEventKind, 1 | -1> = {
  earn: 1,
  recovered: 1,
  refund: 1,
  spend: -1,
  fee: -1,
};

const KIND_LABEL: Record<MoneyEventKind, string> = {
  earn: "Made",
  recovered: "Recovered",
  refund: "Refunded",
  spend: "Spent",
  fee: "Fees",
};

type MoneyTotalsRow = {
  made_cents: number;
  protected_cents: number;
  recovered_cents: number;
  spent_cents: number;
  fees_cents: number;
  net_cents: number;
};

export default async function MoneyPage() {
  const accountId = await getActiveAccountId();
  const supabase = await createClient();

  const { data: events } = accountId
    ? await supabase
        .from("money_events")
        .select("*")
        .eq("account_id", accountId)
        .order("occurred_at", { ascending: false })
        .returns<MoneyEvent[]>()
    : { data: [] as MoneyEvent[] };

  // Totals come from the one canonical formula (public.account_money_totals,
  // see supabase/migrations/20260822165605_money_integrity.sql) rather than
  // being re-derived here -- this page used to reduce over `events` itself,
  // duplicating the exact same formula apps/mobile also reimplemented.
  const { data: totalsRows } = accountId
    ? await supabase.rpc("account_money_totals", { p_account_id: accountId })
    : { data: null };
  const totals = (totalsRows as MoneyTotalsRow[] | null)?.[0] ?? {
    made_cents: 0,
    protected_cents: 0,
    recovered_cents: 0,
    spent_cents: 0,
    fees_cents: 0,
    net_cents: 0,
  };
  const net = totals.net_cents;

  return (
    <div className="flex flex-col gap-8">
      <LedgerPageIntro title="Money" subtitle="Everything you made, protected, and recovered." />

      {/* The hero: one dominant editorial figure, not six equally-weighted
          boxes. Neutral Bone even when positive — a private ledger states
          a number, it doesn't cheer for it. */}
      <LedgerHero
        eyebrow="Current value"
        value={
          <p
            className={`tabular-nums-mono text-5xl ${
              net < 0 ? "text-[var(--color-danger-text)]" : "text-[var(--color-text-primary)]"
            }`}
            style={{ fontFamily: "var(--font-display)", fontWeight: 600 }}
          >
            {formatCents(net)}
          </p>
        }
        action={
          <details className="group">
            <summary className="inline-flex cursor-pointer rounded-[var(--radius-sm)] bg-[var(--color-brand)] px-4 py-2 text-sm font-semibold text-[var(--color-on-accent)] transition-opacity hover:opacity-90">
              Add entry
            </summary>
            <div className="mt-3 max-w-xl">
              <LogEventForm initialRequestId={crypto.randomUUID()} />
            </div>
          </details>
        }
      />

      <div className="grid grid-cols-3 gap-4">
        {(
          [
            ["MADE", totals.made_cents],
            ["PROTECTED", totals.protected_cents],
            ["RECOVERED", totals.recovered_cents],
          ] as const
        ).map(([label, cents]) => (
          <div key={label}>
            <p className="text-[10px] font-semibold tracking-[0.12em] text-[var(--color-text-tertiary)]">
              {label}
            </p>
            <Amount cents={cents} tone="neutral" size="md" className="mt-0.5 font-medium" />
          </div>
        ))}
      </div>

      <Link href="/money/purchases" className="block">
        <LedgerRow>
          <div>
            <p className="text-sm font-semibold text-[var(--color-text-primary)]">
              Purchases, returns &amp; warranties
            </p>
            <p className="mt-0.5 text-xs text-[var(--color-text-tertiary)]">
              Keep what you bought protected.
            </p>
          </div>
          <span aria-hidden className="text-[var(--color-text-tertiary)]">
            →
          </span>
        </LedgerRow>
      </Link>

      <section>
        <LedgerSectionLabel>Ledger</LedgerSectionLabel>
        <div className="mt-1">
          {(events ?? []).length === 0 ? (
            <EmptyState
              title="Your ledger begins with the first recorded value"
              description="Sales, refunds, and manual entries will appear here as they happen."
            />
          ) : (
            (events ?? []).map((event) => (
              <LedgerRow key={event.id}>
                <div>
                  <p className="text-sm font-medium text-[var(--color-text-primary)]">
                    {event.description || KIND_LABEL[event.kind]}
                  </p>
                  <p className="text-xs text-[var(--color-text-tertiary)]">
                    {new Date(event.occurred_at).toLocaleDateString()} ·{" "}
                    {event.source_type ?? "manual"}
                  </p>
                </div>
                <Amount
                  cents={KIND_SIGN[event.kind] * event.amount_cents}
                  tone="auto"
                  signed
                  className="font-medium"
                />
              </LedgerRow>
            ))
          )}
        </div>
      </section>
    </div>
  );
}
