import Link from "next/link";
import type { OpportunityStage } from "@loop/contracts";
import { createClient } from "@/lib/supabase/server";
import { getActiveAccountId } from "@/lib/active-account";
import { Amount } from "@/components/ui/amount";
import { Card } from "@/components/ui/card";
import { EmptyState } from "@/components/ui/empty-state";
import { InlineActionForm } from "@/components/ui/inline-action-form";
import { StatusBadge } from "@/components/ui/status-badge";
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

const STAGE_TONE: Record<
  OpportunityStage,
  "neutral" | "info" | "opportunity" | "warning" | "brand" | "danger"
> = {
  new: "neutral",
  qualifying: "info",
  quoted: "opportunity",
  negotiating: "warning",
  won: "brand",
  lost: "danger",
};

/** One natural next stage, not five equally-weighted buttons — same
    principle as the Quotes page. Terminal stages (won/lost) have none. */
const NEXT_STAGE: Partial<Record<OpportunityStage, OpportunityStage>> = {
  new: "qualifying",
  qualifying: "quoted",
  quoted: "negotiating",
};

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
        <Link
          href="/business"
          className="text-xs text-[var(--color-text-tertiary)] hover:underline"
        >
          ← Business
        </Link>
        <h1 className="mt-1 text-xl font-semibold text-[var(--color-text-primary)]">
          Opportunities
        </h1>
        <p className="mt-1 text-sm text-[var(--color-text-secondary)]">
          MAKE / QuoteCloser. Once qualified, an opportunity is worth writing a{" "}
          <Link href="/business/quotes" className="text-[var(--color-brand-text)] hover:underline">
            quote
          </Link>{" "}
          for.
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
            first — opportunities need one.
          </p>
        ) : (
          <CreateOpportunityForm contacts={contacts ?? []} />
        )}
      </Card>

      <div className="flex flex-col gap-2">
        {(opportunities ?? []).length === 0 ? (
          <EmptyState
            title="No active opportunities"
            description="Add one above to start tracking it."
          />
        ) : (
          (opportunities ?? []).map((opp) => {
            const next = NEXT_STAGE[opp.stage];
            const otherStages = STAGE_OPTIONS.filter((s) => s !== opp.stage && s !== next);
            return (
              <Card
                key={opp.id}
                className="flex flex-col gap-2 px-4 py-3 sm:flex-row sm:items-center sm:justify-between"
              >
                <div>
                  <p className="text-sm font-medium text-[var(--color-text-primary)]">
                    {opp.title}
                  </p>
                  <p className="text-xs text-[var(--color-text-tertiary)]">
                    {opp.contacts?.display_name ?? "Unknown contact"}
                    {opp.estimated_value_cents !== null ? (
                      <>
                        {" · "}
                        <Amount cents={opp.estimated_value_cents} className="text-xs" />
                      </>
                    ) : null}
                  </p>
                </div>
                <div className="flex flex-wrap items-center gap-3">
                  <StatusBadge label={opp.stage} tone={STAGE_TONE[opp.stage]} />
                  {next ? (
                    <InlineActionForm
                      action={setOpportunityStage.bind(null, opp.id, next)}
                      label={`Mark ${next}`}
                      buttonClassName="text-xs font-medium text-[var(--color-brand-text)] hover:underline"
                    />
                  ) : null}
                  {otherStages.length > 0 ? (
                    <details className="relative">
                      <summary className="cursor-pointer list-none text-xs text-[var(--color-text-tertiary)] hover:text-[var(--color-text-secondary)]">
                        Other…
                      </summary>
                      <div className="absolute right-0 z-10 mt-1 flex flex-col gap-1 rounded-[var(--radius-sm)] border border-[var(--color-border-subtle)] bg-[var(--color-surface)] p-2 shadow-lg">
                        {otherStages.map((stage) => (
                          <InlineActionForm
                            key={stage}
                            action={setOpportunityStage.bind(null, opp.id, stage)}
                            label={`Mark ${stage}`}
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
