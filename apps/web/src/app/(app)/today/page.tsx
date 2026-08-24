import type { Action } from "@loop/contracts";
import { createClient } from "@/lib/supabase/server";
import { getActiveAccountId } from "@/lib/active-account";
import { EmptyState } from "@/components/ui/empty-state";
import { InlineActionForm } from "@/components/ui/inline-action-form";
import { LedgerHero, LedgerPageIntro, LedgerRow, LedgerSectionLabel } from "@/components/ui/ledger";
import { QuickAddForm } from "./quick-add-form";
import { setActionStatus } from "./actions";

function isOverdue(dueAt: string | null): boolean {
  if (!dueAt) return false;
  return new Date(dueAt).getTime() < Date.now();
}

function formatDue(dueAt: string): string {
  const date = new Date(dueAt);
  const today = new Date();
  const sameDay = date.toDateString() === today.toDateString();
  if (sameDay) return "Today";
  return date.toLocaleDateString(undefined, { month: "short", day: "numeric" });
}

export default async function TodayPage() {
  const accountId = await getActiveAccountId();
  const supabase = await createClient();

  if (accountId) {
    // Best-effort: turn due quote/return/warranty deadlines into actions
    // before reading the list. A transient failure here should never block
    // showing whatever actions already exist -- see
    // supabase/migrations/20260822164226_today_automation.sql.
    try {
      await supabase.rpc("generate_today_actions", { p_account_id: accountId });
    } catch {
      // Ignored -- see comment above.
    }
  }

  const { data: actions } = accountId
    ? await supabase
        .from("actions")
        .select("*")
        .eq("account_id", accountId)
        .neq("status", "dismissed")
        .order("status", { ascending: true })
        .order("due_at", { ascending: true, nullsFirst: false })
        .order("created_at", { ascending: false })
        .returns<Action[]>()
    : { data: [] as Action[] };

  const open = (actions ?? []).filter((a) => a.status === "open" || a.status === "snoozed");
  const done = (actions ?? []).filter((a) => a.status === "done").slice(0, 2);
  const next = open[0];

  return (
    <div className="flex flex-col gap-8">
      <LedgerPageIntro
        title="Today"
        subtitle={new Intl.DateTimeFormat(undefined, {
          weekday: "long",
          month: "long",
          day: "numeric",
        }).format(new Date())}
      />

      {next ? (
        <LedgerHero
          eyebrow="Next"
          value={
            <p
              className="text-2xl text-[var(--color-text-primary)]"
              style={{ fontFamily: "var(--font-display)", fontWeight: 600 }}
            >
              {next.title}
            </p>
          }
          detail={
            next.due_at
              ? `${isOverdue(next.due_at) ? "Overdue" : "Due"} ${formatDue(next.due_at)}`
              : undefined
          }
          action={
            <div className="flex items-center gap-3">
              <InlineActionForm
                action={setActionStatus.bind(null, next.id, "done")}
                label="Mark done"
                buttonClassName="rounded-[var(--radius-sm)] bg-[var(--color-brand)] px-4 py-2 text-sm font-semibold text-[var(--color-on-accent)] transition-opacity hover:opacity-90"
              />
              <InlineActionForm
                action={setActionStatus.bind(null, next.id, "dismissed")}
                label="Dismiss"
                buttonClassName="px-2 py-2 text-xs text-[var(--color-text-tertiary)] transition-opacity hover:opacity-70"
              />
            </div>
          }
        />
      ) : (
        <div>
          <EmptyState title="You’re clear." description="Nothing needs your attention right now." />
        </div>
      )}

      <details className="group">
        <summary className="cursor-pointer text-sm font-medium text-[var(--color-brand-text)] hover:opacity-70">
          Add an action
        </summary>
        <div className="mt-3 max-w-xl">
          <QuickAddForm />
        </div>
      </details>

      {open.length > 1 ? (
        <section>
          <LedgerSectionLabel>Up next</LedgerSectionLabel>
          <div className="mt-1">
            {open.slice(1, 5).map((action) => {
              const overdue = isOverdue(action.due_at);
              return (
                <LedgerRow key={action.id}>
                  <div className="flex flex-col gap-0.5">
                    <p className="text-sm font-medium text-[var(--color-text-primary)]">
                      {action.title}
                    </p>
                    {action.due_at ? (
                      <p
                        className={`text-xs ${
                          overdue
                            ? "font-medium text-[var(--color-danger-text)]"
                            : "text-[var(--color-text-tertiary)]"
                        }`}
                      >
                        {overdue ? "Overdue · " : "Due "}
                        {formatDue(action.due_at)}
                      </p>
                    ) : null}
                  </div>
                  <div className="flex items-center gap-2">
                    <InlineActionForm
                      action={setActionStatus.bind(null, action.id, "done")}
                      label="Done"
                      buttonClassName="text-xs font-medium text-[var(--color-brand-text)] transition-opacity hover:opacity-70"
                    />
                  </div>
                </LedgerRow>
              );
            })}
            {open.length > 5 ? (
              <p className="mt-2 text-xs text-[var(--color-text-tertiary)]">
                {open.length - 5} more waiting
              </p>
            ) : null}
          </div>
        </section>
      ) : null}

      {done.length > 0 ? (
        <section>
          <LedgerSectionLabel>Recently done</LedgerSectionLabel>
          {done.map((action) => (
            <LedgerRow key={action.id}>
              <p className="text-sm text-[var(--color-text-tertiary)] line-through">
                {action.title}
              </p>
              <InlineActionForm
                action={setActionStatus.bind(null, action.id, "open")}
                label="Reopen"
                buttonClassName="text-xs text-[var(--color-text-tertiary)] transition-opacity hover:opacity-70"
              />
            </LedgerRow>
          ))}
        </section>
      ) : null}
    </div>
  );
}
