import Link from "next/link";
import type { OpportunityStage } from "@loop/contracts";
import { createClient } from "@/lib/supabase/server";
import { getActiveAccountId } from "@/lib/active-account";
import { CreateOpportunityForm } from "./create-opportunity-form";
import { setOpportunityStage } from "./actions";

type OpportunityRow = {
  id: string;
  title: string;
  stage: OpportunityStage;
  estimated_value_cents: number | null;
  contacts: { id: string; display_name: string } | null;
};

const STAGE_OPTIONS: OpportunityStage[] = [
  "new",
  "qualifying",
  "quoted",
  "negotiating",
  "won",
  "lost",
];

const STAGE_STYLES: Record<OpportunityStage, string> = {
  new: "bg-zinc-100 text-zinc-600 dark:bg-zinc-900 dark:text-zinc-400",
  qualifying: "bg-blue-100 text-blue-700 dark:bg-blue-950 dark:text-blue-400",
  quoted: "bg-amber-100 text-amber-700 dark:bg-amber-950 dark:text-amber-400",
  negotiating: "bg-purple-100 text-purple-700 dark:bg-purple-950 dark:text-purple-400",
  won: "bg-emerald-100 text-emerald-700 dark:bg-emerald-950 dark:text-emerald-400",
  lost: "bg-red-100 text-red-700 dark:bg-red-950 dark:text-red-400",
};

function formatCents(cents: number | null): string {
  if (cents === null) return "—";
  return (cents / 100).toLocaleString(undefined, { style: "currency", currency: "USD" });
}

export default async function OpportunitiesPage() {
  const accountId = await getActiveAccountId();
  const supabase = await createClient();

  const [{ data: opportunities }, { data: contacts }] = await Promise.all([
    accountId
      ? supabase
          .from("opportunities")
          .select("id, title, stage, estimated_value_cents, contacts(id, display_name)")
          .eq("account_id", accountId)
          .order("created_at", { ascending: false })
          .returns<OpportunityRow[]>()
      : Promise.resolve({ data: [] as OpportunityRow[] }),
    accountId
      ? supabase
          .from("contacts")
          .select("id, display_name")
          .eq("account_id", accountId)
          .order("display_name", { ascending: true })
      : Promise.resolve({ data: [] as { id: string; display_name: string }[] }),
  ]);

  return (
    <div className="flex flex-col gap-6">
      <div>
        <Link href="/business" className="text-xs text-zinc-500 hover:underline dark:text-zinc-400">
          ← Business
        </Link>
        <h1 className="mt-1 text-xl font-semibold text-zinc-950 dark:text-zinc-50">Opportunities</h1>
        <p className="mt-1 text-sm text-zinc-500 dark:text-zinc-400">
          MAKE / QuoteCloser. Once qualified, an opportunity is worth writing a{" "}
          <Link href="/business/quotes" className="underline">
            quote
          </Link>{" "}
          for.
        </p>
      </div>

      <div className="rounded-2xl border border-zinc-200 bg-white p-4 dark:border-zinc-800 dark:bg-zinc-950">
        {(contacts ?? []).length === 0 ? (
          <p className="text-sm text-zinc-500 dark:text-zinc-400">
            Add a <Link href="/business/contacts" className="underline">contact</Link> first —
            opportunities need one.
          </p>
        ) : (
          <CreateOpportunityForm contacts={contacts ?? []} />
        )}
      </div>

      <ul className="flex flex-col gap-2">
        {(opportunities ?? []).length === 0 ? (
          <p className="text-sm text-zinc-500 dark:text-zinc-400">No opportunities yet.</p>
        ) : (
          (opportunities ?? []).map((opp) => (
            <li
              key={opp.id}
              className="flex flex-col gap-2 rounded-xl border border-zinc-200 bg-white px-4 py-3 dark:border-zinc-800 dark:bg-zinc-950 sm:flex-row sm:items-center sm:justify-between"
            >
              <div>
                <p className="text-sm font-medium text-zinc-950 dark:text-zinc-50">{opp.title}</p>
                <p className="text-xs text-zinc-500 dark:text-zinc-400">
                  {opp.contacts?.display_name ?? "Unknown contact"} · {formatCents(opp.estimated_value_cents)}
                </p>
              </div>
              <div className="flex flex-wrap items-center gap-2">
                <span className={`rounded-full px-2 py-0.5 text-xs font-medium ${STAGE_STYLES[opp.stage]}`}>
                  {opp.stage}
                </span>
                {STAGE_OPTIONS.filter((s) => s !== opp.stage).map((stage) => (
                  <form key={stage} action={setOpportunityStage.bind(null, opp.id, stage)}>
                    <button
                      type="submit"
                      className="text-xs font-medium text-zinc-400 hover:underline dark:text-zinc-500"
                    >
                      {stage}
                    </button>
                  </form>
                ))}
              </div>
            </li>
          ))
        )}
      </ul>
    </div>
  );
}
