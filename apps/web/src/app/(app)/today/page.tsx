import type { Action } from "@loop/contracts";
import { createClient } from "@/lib/supabase/server";
import { getActiveAccountId } from "@/lib/active-account";
import { Card } from "@/components/ui/card";
import { EmptyState } from "@/components/ui/empty-state";
import { InlineActionForm } from "@/components/ui/inline-action-form";
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
    // supabase/migrations/20260822160000_today_automation.sql.
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
  const done = (actions ?? []).filter((a) => a.status === "done");

  return (
    <div className="flex flex-col gap-6">
      <h1 className="text-xl font-semibold text-[var(--color-text-primary)]">Today</h1>

      <QuickAddForm />

      <div className="flex flex-col gap-2">
        {open.length === 0 ? (
          <EmptyState
            title="Nothing needs attention"
            description="Quotes to follow up, return deadlines, and resell opportunities will show up here as they come due."
          />
        ) : (
          open.map((action) => {
            const overdue = isOverdue(action.due_at);
            return (
              <Card key={action.id} className="flex items-center justify-between px-4 py-3">
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
                <div className="flex items-center gap-3">
                  <InlineActionForm
                    action={setActionStatus.bind(null, action.id, "done")}
                    label="Done"
                    buttonClassName="text-xs font-medium text-[var(--color-brand-text)] transition-opacity hover:opacity-70"
                  />
                  <InlineActionForm
                    action={setActionStatus.bind(null, action.id, "dismissed")}
                    label="Dismiss"
                    buttonClassName="text-xs text-[var(--color-text-tertiary)] transition-opacity hover:opacity-70"
                  />
                </div>
              </Card>
            );
          })
        )}
      </div>

      {done.length > 0 ? (
        <div className="flex flex-col gap-2">
          <h2 className="text-xs font-medium uppercase tracking-wide text-[var(--color-text-tertiary)]">
            Recently done
          </h2>
          {done.map((action) => (
            <div
              key={action.id}
              className="flex items-center justify-between rounded-[var(--radius-md)] px-4 py-2"
            >
              <p className="text-sm text-[var(--color-text-tertiary)] line-through">
                {action.title}
              </p>
              <InlineActionForm
                action={setActionStatus.bind(null, action.id, "open")}
                label="Reopen"
                buttonClassName="text-xs text-[var(--color-text-tertiary)] transition-opacity hover:opacity-70"
              />
            </div>
          ))}
        </div>
      ) : null}
    </div>
  );
}
