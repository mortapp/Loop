import Link from "next/link";
import type { MoneyEvent, MoneyEventKind } from "@loop/contracts";
import { createClient } from "@/lib/supabase/server";
import { getActiveAccountId } from "@/lib/active-account";
import { LogEventForm } from "./log-event-form";

const KIND_STYLES: Record<MoneyEventKind, string> = {
  earn: "text-emerald-600 dark:text-emerald-400",
  recovered: "text-emerald-600 dark:text-emerald-400",
  refund: "text-blue-600 dark:text-blue-400",
  spend: "text-red-600 dark:text-red-400",
  fee: "text-red-600 dark:text-red-400",
};

const KIND_SIGN: Record<MoneyEventKind, 1 | -1> = {
  earn: 1,
  recovered: 1,
  refund: 1,
  spend: -1,
  fee: -1,
};

function formatCents(cents: number): string {
  return (cents / 100).toLocaleString(undefined, { style: "currency", currency: "USD" });
}

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
    <div className="flex flex-col gap-6">
      <div>
        <h1 className="text-xl font-semibold text-zinc-950 dark:text-zinc-50">Money</h1>
        <p className="mt-1 text-sm text-zinc-500 dark:text-zinc-400">
          Everything earned, spent, refunded, and recovered — the append-only ledger every engine
          writes to.{" "}
          <Link href="/money/purchases" className="underline">
            Purchases &amp; returns →
          </Link>
        </p>
      </div>

      <div className="grid grid-cols-2 gap-3 sm:grid-cols-3">
        <div className="rounded-2xl border border-zinc-200 bg-white p-4 dark:border-zinc-800 dark:bg-zinc-950">
          <p className="text-xs text-zinc-500 dark:text-zinc-400">Net</p>
          <p className={`mt-1 text-lg font-semibold ${net >= 0 ? "text-emerald-600 dark:text-emerald-400" : "text-red-600 dark:text-red-400"}`}>
            {formatCents(net)}
          </p>
        </div>
        {(["earn", "recovered", "refund", "spend", "fee"] as MoneyEventKind[]).map((kind) => (
          <div
            key={kind}
            className="rounded-2xl border border-zinc-200 bg-white p-4 dark:border-zinc-800 dark:bg-zinc-950"
          >
            <p className="text-xs capitalize text-zinc-500 dark:text-zinc-400">{kind}</p>
            <p className={`mt-1 text-lg font-semibold ${KIND_STYLES[kind]}`}>
              {formatCents(totals[kind] ?? 0)}
            </p>
          </div>
        ))}
      </div>

      <div className="rounded-2xl border border-zinc-200 bg-white p-4 dark:border-zinc-800 dark:bg-zinc-950">
        <h2 className="mb-3 text-sm font-semibold text-zinc-950 dark:text-zinc-50">Log a manual entry</h2>
        <LogEventForm />
      </div>

      <ul className="flex flex-col gap-2">
        {(events ?? []).length === 0 ? (
          <p className="text-sm text-zinc-500 dark:text-zinc-400">No money events yet.</p>
        ) : (
          (events ?? []).map((event) => (
            <li
              key={event.id}
              className="flex items-center justify-between rounded-xl border border-zinc-200 bg-white px-4 py-3 dark:border-zinc-800 dark:bg-zinc-950"
            >
              <div>
                <p className="text-sm font-medium text-zinc-950 dark:text-zinc-50">
                  {event.description || event.kind}
                </p>
                <p className="text-xs text-zinc-500 dark:text-zinc-400">
                  {new Date(event.occurred_at).toLocaleString()} · {event.source_type ?? "manual"}
                </p>
              </div>
              <p className={`text-sm font-semibold ${KIND_STYLES[event.kind]}`}>
                {KIND_SIGN[event.kind] > 0 ? "+" : "-"}
                {formatCents(event.amount_cents)}
              </p>
            </li>
          ))
        )}
      </ul>
    </div>
  );
}
