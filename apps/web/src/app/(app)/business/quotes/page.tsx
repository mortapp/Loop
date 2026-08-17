import Link from "next/link";
import type { QuoteStatus } from "@loop/contracts";
import { createClient } from "@/lib/supabase/server";
import { getActiveAccountId } from "@/lib/active-account";
import { CreateQuoteForm } from "./create-quote-form";
import { setQuoteStatus } from "./actions";

type QuoteRow = {
  id: string;
  quote_number: string;
  status: QuoteStatus;
  total_cents: number;
  currency: string;
  contacts: { id: string; display_name: string } | null;
};

const STATUS_OPTIONS: QuoteStatus[] = ["draft", "sent", "viewed", "accepted", "declined", "expired"];

const STATUS_STYLES: Record<QuoteStatus, string> = {
  draft: "bg-zinc-100 text-zinc-600 dark:bg-zinc-900 dark:text-zinc-400",
  sent: "bg-blue-100 text-blue-700 dark:bg-blue-950 dark:text-blue-400",
  viewed: "bg-purple-100 text-purple-700 dark:bg-purple-950 dark:text-purple-400",
  accepted: "bg-emerald-100 text-emerald-700 dark:bg-emerald-950 dark:text-emerald-400",
  declined: "bg-red-100 text-red-700 dark:bg-red-950 dark:text-red-400",
  expired: "bg-amber-100 text-amber-700 dark:bg-amber-950 dark:text-amber-400",
};

function formatCents(cents: number, currency: string): string {
  return (cents / 100).toLocaleString(undefined, { style: "currency", currency });
}

export default async function QuotesPage() {
  const accountId = await getActiveAccountId();
  const supabase = await createClient();

  const [{ data: quotes }, { data: contacts }, { data: opportunities }] = await Promise.all([
    accountId
      ? supabase
          .from("quotes")
          .select("id, quote_number, status, total_cents, currency, contacts(id, display_name)")
          .eq("account_id", accountId)
          .order("created_at", { ascending: false })
          .returns<QuoteRow[]>()
      : Promise.resolve({ data: [] as QuoteRow[] }),
    accountId
      ? supabase
          .from("contacts")
          .select("id, display_name")
          .eq("account_id", accountId)
          .order("display_name", { ascending: true })
      : Promise.resolve({ data: [] as { id: string; display_name: string }[] }),
    accountId
      ? supabase
          .from("opportunities")
          .select("id, title")
          .eq("account_id", accountId)
          .order("created_at", { ascending: false })
      : Promise.resolve({ data: [] as { id: string; title: string }[] }),
  ]);

  return (
    <div className="flex flex-col gap-6">
      <div>
        <Link href="/business" className="text-xs text-zinc-500 hover:underline dark:text-zinc-400">
          ← Business
        </Link>
        <h1 className="mt-1 text-xl font-semibold text-zinc-950 dark:text-zinc-50">Quotes</h1>
        <p className="mt-1 text-sm text-zinc-500 dark:text-zinc-400">
          MAKE / QuoteCloser. An accepted quote is expected to produce a{" "}
          <Link href="/money" className="underline">
            money_events
          </Link>{" "}
          row once that wiring exists.
        </p>
      </div>

      <div className="rounded-2xl border border-zinc-200 bg-white p-4 dark:border-zinc-800 dark:bg-zinc-950">
        {(contacts ?? []).length === 0 ? (
          <p className="text-sm text-zinc-500 dark:text-zinc-400">
            Add a <Link href="/business/contacts" className="underline">contact</Link> first — quotes
            need one.
          </p>
        ) : (
          <CreateQuoteForm contacts={contacts ?? []} opportunities={opportunities ?? []} />
        )}
      </div>

      <ul className="flex flex-col gap-2">
        {(quotes ?? []).length === 0 ? (
          <p className="text-sm text-zinc-500 dark:text-zinc-400">No quotes yet.</p>
        ) : (
          (quotes ?? []).map((quote) => (
            <li
              key={quote.id}
              className="flex flex-col gap-2 rounded-xl border border-zinc-200 bg-white px-4 py-3 dark:border-zinc-800 dark:bg-zinc-950 sm:flex-row sm:items-center sm:justify-between"
            >
              <div>
                <p className="text-sm font-medium text-zinc-950 dark:text-zinc-50">
                  {quote.quote_number} · {formatCents(quote.total_cents, quote.currency)}
                </p>
                <p className="text-xs text-zinc-500 dark:text-zinc-400">
                  {quote.contacts?.display_name ?? "Unknown contact"}
                </p>
              </div>
              <div className="flex flex-wrap items-center gap-2">
                <span className={`rounded-full px-2 py-0.5 text-xs font-medium ${STATUS_STYLES[quote.status]}`}>
                  {quote.status}
                </span>
                {STATUS_OPTIONS.filter((s) => s !== quote.status).map((status) => (
                  <form key={status} action={setQuoteStatus.bind(null, quote.id, status)}>
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
