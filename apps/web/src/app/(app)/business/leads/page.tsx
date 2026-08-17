import Link from "next/link";
import type { LeadStatus } from "@loop/contracts";
import { createClient } from "@/lib/supabase/server";
import { getActiveAccountId } from "@/lib/active-account";
import { CreateLeadForm } from "./create-lead-form";
import { setLeadStatus } from "./actions";

type LeadRow = {
  id: string;
  status: LeadStatus;
  source: string | null;
  notes: string | null;
  contacts: { id: string; display_name: string } | null;
};

const STATUS_OPTIONS: LeadStatus[] = ["new", "contacted", "qualified", "disqualified", "converted"];

const STATUS_STYLES: Record<LeadStatus, string> = {
  new: "bg-zinc-100 text-zinc-600 dark:bg-zinc-900 dark:text-zinc-400",
  contacted: "bg-blue-100 text-blue-700 dark:bg-blue-950 dark:text-blue-400",
  qualified: "bg-amber-100 text-amber-700 dark:bg-amber-950 dark:text-amber-400",
  disqualified: "bg-red-100 text-red-700 dark:bg-red-950 dark:text-red-400",
  converted: "bg-emerald-100 text-emerald-700 dark:bg-emerald-950 dark:text-emerald-400",
};

export default async function LeadsPage() {
  const accountId = await getActiveAccountId();
  const supabase = await createClient();

  const [{ data: leads }, { data: contacts }] = await Promise.all([
    accountId
      ? supabase
          .from("leads")
          .select("id, status, source, notes, contacts(id, display_name)")
          .eq("account_id", accountId)
          .order("created_at", { ascending: false })
          .returns<LeadRow[]>()
      : Promise.resolve({ data: [] as LeadRow[] }),
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
        <h1 className="mt-1 text-xl font-semibold text-zinc-950 dark:text-zinc-50">Leads</h1>
        <p className="mt-1 text-sm text-zinc-500 dark:text-zinc-400">
          MAKE / QuoteCloser. Track interest before it becomes an opportunity worth quoting.
        </p>
      </div>

      <div className="rounded-2xl border border-zinc-200 bg-white p-4 dark:border-zinc-800 dark:bg-zinc-950">
        {(contacts ?? []).length === 0 ? (
          <p className="text-sm text-zinc-500 dark:text-zinc-400">
            Add a <Link href="/business/contacts" className="underline">contact</Link> first — leads
            need one.
          </p>
        ) : (
          <CreateLeadForm contacts={contacts ?? []} />
        )}
      </div>

      <ul className="flex flex-col gap-2">
        {(leads ?? []).length === 0 ? (
          <p className="text-sm text-zinc-500 dark:text-zinc-400">No leads yet.</p>
        ) : (
          (leads ?? []).map((lead) => (
            <li
              key={lead.id}
              className="flex flex-col gap-2 rounded-xl border border-zinc-200 bg-white px-4 py-3 dark:border-zinc-800 dark:bg-zinc-950 sm:flex-row sm:items-center sm:justify-between"
            >
              <div>
                <p className="text-sm font-medium text-zinc-950 dark:text-zinc-50">
                  {lead.contacts?.display_name ?? "Unknown contact"}
                </p>
                <p className="text-xs text-zinc-500 dark:text-zinc-400">
                  {[lead.source, lead.notes].filter(Boolean).join(" · ") || "No details"}
                </p>
              </div>
              <div className="flex flex-wrap items-center gap-2">
                <span className={`rounded-full px-2 py-0.5 text-xs font-medium ${STATUS_STYLES[lead.status]}`}>
                  {lead.status}
                </span>
                {STATUS_OPTIONS.filter((s) => s !== lead.status).map((status) => (
                  <form key={status} action={setLeadStatus.bind(null, lead.id, status)}>
                    <button
                      type="submit"
                      className="text-xs font-medium text-zinc-400 hover:underline dark:text-zinc-500"
                    >
                      {status}
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
