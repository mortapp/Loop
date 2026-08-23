import Link from "next/link";
import type { LeadStatus } from "@loop/contracts";
import { createClient } from "@/lib/supabase/server";
import { getActiveAccountId } from "@/lib/active-account";
import { Card } from "@/components/ui/card";
import { EmptyState } from "@/components/ui/empty-state";
import { InlineActionForm } from "@/components/ui/inline-action-form";
import { StatusBadge } from "@/components/ui/status-badge";
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

const STATUS_TONE: Record<LeadStatus, "neutral" | "info" | "opportunity" | "danger" | "brand"> = {
  new: "neutral",
  contacted: "info",
  qualified: "opportunity",
  disqualified: "danger",
  converted: "brand",
};

/** One natural next status, not four equally-weighted buttons. */
const NEXT_STATUS: Partial<Record<LeadStatus, LeadStatus>> = {
  new: "contacted",
  contacted: "qualified",
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
        <Link
          href="/business"
          className="text-xs text-[var(--color-text-tertiary)] hover:underline"
        >
          ← Business
        </Link>
        <h1 className="mt-1 text-xl font-semibold text-[var(--color-text-primary)]">Leads</h1>
        <p className="mt-1 text-sm text-[var(--color-text-secondary)]">
          MAKE / QuoteCloser. Track interest before it becomes an opportunity worth quoting.
        </p>
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
            first — leads need one.
          </p>
        ) : (
          <CreateLeadForm contacts={contacts ?? []} />
        )}
      </Card>

      <div className="flex flex-col gap-2">
        {(leads ?? []).length === 0 ? (
          <EmptyState title="No leads yet" description="Add one above to start tracking it." />
        ) : (
          (leads ?? []).map((lead) => {
            const next = NEXT_STATUS[lead.status];
            const otherStatuses = STATUS_OPTIONS.filter((s) => s !== lead.status && s !== next);
            return (
              <Card
                key={lead.id}
                className="flex flex-col gap-2 px-4 py-3 sm:flex-row sm:items-center sm:justify-between"
              >
                <div>
                  <p className="text-sm font-medium text-[var(--color-text-primary)]">
                    {lead.contacts?.display_name ?? "Unknown contact"}
                  </p>
                  <p className="text-xs text-[var(--color-text-tertiary)]">
                    {[lead.source, lead.notes].filter(Boolean).join(" · ") || "No details"}
                  </p>
                </div>
                <div className="flex flex-wrap items-center gap-3">
                  <StatusBadge label={lead.status} tone={STATUS_TONE[lead.status]} />
                  {next ? (
                    <InlineActionForm
                      action={setLeadStatus.bind(null, lead.id, next)}
                      label={`Mark ${next}`}
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
                            action={setLeadStatus.bind(null, lead.id, status)}
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
