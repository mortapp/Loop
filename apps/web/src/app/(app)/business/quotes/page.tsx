import Link from "next/link";
import type { QuoteStatus } from "@loop/contracts";
import { createClient } from "@/lib/supabase/server";
import { getActiveAccountId } from "@/lib/active-account";
import { Amount } from "@/components/ui/amount";
import { Card } from "@/components/ui/card";
import { EmptyState } from "@/components/ui/empty-state";
import { InlineActionForm } from "@/components/ui/inline-action-form";
import { StatusBadge } from "@/components/ui/status-badge";
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

const STATUS_OPTIONS: QuoteStatus[] = [
  "draft",
  "sent",
  "viewed",
  "accepted",
  "declined",
  "expired",
];

const STATUS_TONE: Record<QuoteStatus, "neutral" | "info" | "brand" | "danger" | "warning"> = {
  draft: "neutral",
  sent: "info",
  viewed: "info",
  accepted: "brand",
  declined: "danger",
  expired: "warning",
};

/** The single natural next step for a quote in this status — this is the
    one action rendered prominently. Terminal statuses (accepted/declined/
    expired) have none; every other transition is still reachable, just
    not all shown with equal visual weight (Part 10 of the design brief:
    "do not show 8 equally weighted buttons"). */
const NEXT_STATUS: Partial<Record<QuoteStatus, { status: QuoteStatus; label: string }>> = {
  draft: { status: "sent", label: "Mark sent" },
  sent: { status: "viewed", label: "Mark viewed" },
  viewed: { status: "accepted", label: "Mark accepted" },
};

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
        <Link
          href="/business"
          className="text-xs text-[var(--color-text-tertiary)] hover:underline"
        >
          ← Business
        </Link>
        <h1 className="mt-1 text-xl font-semibold text-[var(--color-text-primary)]">Quotes</h1>
      </div>

      <Card className="p-4">
        {(contacts ?? []).length === 0 ? (
          <p className="text-sm text-[var(--color-text-secondary)]">
            Add a{" "}
            <Link
              href="/business/contacts"
              className="text-[var(--color-brand-text)] hover:underline"
            >
              contact
            </Link>{" "}
            first — quotes need one.
          </p>
        ) : (
          <CreateQuoteForm contacts={contacts ?? []} opportunities={opportunities ?? []} />
        )}
      </Card>

      <div className="flex flex-col gap-2">
        {(quotes ?? []).length === 0 ? (
          <EmptyState title="No quotes yet" description="Create one above to get started." />
        ) : (
          (quotes ?? []).map((quote) => {
            const next = NEXT_STATUS[quote.status];
            const otherStatuses = STATUS_OPTIONS.filter(
              (s) => s !== quote.status && s !== next?.status,
            );
            return (
              <Card
                key={quote.id}
                className="flex flex-col gap-2 px-4 py-3 sm:flex-row sm:items-center sm:justify-between"
              >
                <div>
                  <p className="text-sm font-medium text-[var(--color-text-primary)]">
                    {quote.quote_number} ·{" "}
                    <Amount
                      cents={quote.total_cents}
                      currency={quote.currency}
                      className="text-sm"
                    />
                  </p>
                  <p className="text-xs text-[var(--color-text-tertiary)]">
                    {quote.contacts?.display_name ?? "Unknown contact"}
                  </p>
                </div>
                <div className="flex flex-wrap items-center gap-3">
                  <StatusBadge label={quote.status} tone={STATUS_TONE[quote.status]} />
                  {next ? (
                    <InlineActionForm
                      action={setQuoteStatus.bind(null, quote.id, next.status)}
                      label={next.label}
                      buttonClassName="text-xs font-medium text-[var(--color-brand-text)] hover:underline"
                    />
                  ) : null}
                  {otherStatuses.length > 0 ? (
                    <details className="relative">
                      <summary className="cursor-pointer list-none text-xs text-[var(--color-text-tertiary)] hover:text-[var(--color-text-secondary)]">
                        Other…
                      </summary>
                      <div className="absolute right-0 z-10 mt-1 flex flex-col gap-1 rounded-[var(--radius-sm)] border border-[var(--color-border-subtle)] bg-[var(--color-surface)] p-2 shadow-lg">
                        {otherStatuses.map((status) => (
                          <InlineActionForm
                            key={status}
                            action={setQuoteStatus.bind(null, quote.id, status)}
                            label={`Mark ${status}`}
                            formClassName="w-full"
                            buttonClassName="w-full whitespace-nowrap rounded px-2 py-1 text-left text-xs text-[var(--color-text-secondary)] hover:bg-[var(--color-surface-hover)]"
                            errorClassName="w-48 whitespace-normal px-2"
                          />
                        ))}
                      </div>
                    </details>
                  ) : null}
                </div>
              </Card>
            );
          })
        )}
      </div>
    </div>
  );
}
