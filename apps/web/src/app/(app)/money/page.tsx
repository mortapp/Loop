import Link from "next/link";
import type { MoneyEvent, MoneyEventKind } from "@loop/contracts";
import { createClient } from "@/lib/supabase/server";
import { getActiveAccountId } from "@/lib/active-account";
import { Amount } from "@/components/ui/amount";
import { Card } from "@/components/ui/card";
import { EmptyState } from "@/components/ui/empty-state";
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

  const totals = (events ?? []).reduce(
    (acc, event) => {
      acc[event.kind] = (acc[event.kind] ?? 0) + event.amount_cents;
      return acc;
    },
    {} as Record<MoneyEventKind, number>,
  );

  const net = (events ?? []).reduce((sum, e) => sum + KIND_SIGN[e.kind] * e.amount_cents, 0);

  return (
    <div className="flex flex-col gap-8">
      <div className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold text-[var(--color-text-primary)]">Money</h1>
        <Link
          href="/money/purchases"
          className="text-sm font-medium text-[var(--color-brand-text)] hover:opacity-70"
        >
          Purchases &amp; returns →
        </Link>
      </div>

      {/* One dominant figure, not six equally-weighted boxes — Net is what
          answers "how am I doing," everything else is supporting detail. */}
      <div>
        <p className="text-sm text-[var(--color-text-tertiary)]">Net through LOOP</p>
        <Amount cents={net} tone="auto" signed size="lg" className="mt-1" />
      </div>

      <div className="grid grid-cols-2 gap-3 sm:grid-cols-5">
        {(["earn", "recovered", "refund", "spend", "fee"] as MoneyEventKind[]).map((kind) => (
          <div key={kind}>
            <p className="text-xs text-[var(--color-text-tertiary)]">{KIND_LABEL[kind]}</p>
            <Amount cents={totals[kind] ?? 0} tone="neutral" size="sm" className="mt-0.5 font-medium" />
          </div>
        ))}
      </div>

      <details className="group">
        <summary className="cursor-pointer text-sm font-medium text-[var(--color-text-secondary)] hover:text-[var(--color-text-primary)]">
          Log a manual entry
        </summary>
        <div className="mt-3">
          <LogEventForm />
        </div>
      </details>

      <div className="flex flex-col gap-2">
        {(events ?? []).length === 0 ? (
          <EmptyState
            title="No recorded value yet"
            description="Sales, refunds, and manual entries will appear here as they happen."
          />
        ) : (
          (events ?? []).map((event) => (
            <Card key={event.id} className="flex items-center justify-between px-4 py-3">
              <div>
                <p className="text-sm font-medium text-[var(--color-text-primary)]">
                  {event.description || KIND_LABEL[event.kind]}
                </p>
                <p className="text-xs text-[var(--color-text-tertiary)]">
                  {new Date(event.occurred_at).toLocaleDateString()} · {event.source_type ?? "manual"}
                </p>
              </div>
              <Amount
                cents={KIND_SIGN[event.kind] * event.amount_cents}
                tone="auto"
                signed
                className="font-medium"
              />
            </Card>
          ))
        )}
      </div>
    </div>
  );
}
