import type { Action } from "@loop/contracts";
import { createClient } from "@/lib/supabase/server";
import { getActiveAccountId } from "@/lib/active-account";
import { QuickAddForm } from "./quick-add-form";
import { setActionStatus } from "./actions";

export default async function TodayPage() {
  const accountId = await getActiveAccountId();
  const supabase = await createClient();

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
      <div>
        <h1 className="text-xl font-semibold text-zinc-950 dark:text-zinc-50">Today</h1>
        <p className="mt-1 text-sm text-zinc-500 dark:text-zinc-400">
          Your unified queue. Once MAKE/PROTECT/RECOVER workflows exist, quotes to send, returns
          nearing their window, and warranties about to expire will show up here automatically —
          for now, this is a plain shared task list backed by the same <code>actions</code> table.
        </p>
      </div>

      <QuickAddForm />

      <div className="flex flex-col gap-2">
        {open.length === 0 ? (
          <p className="text-sm text-zinc-500 dark:text-zinc-400">Nothing open. Add something above.</p>
        ) : (
          open.map((action) => (
            <div
              key={action.id}
              className="flex items-center justify-between rounded-xl border border-zinc-200 bg-white px-4 py-3 dark:border-zinc-800 dark:bg-zinc-950"
            >
              <div>
                <p className="text-sm font-medium text-zinc-950 dark:text-zinc-50">{action.title}</p>
                {action.due_at ? (
                  <p className="text-xs text-zinc-500 dark:text-zinc-400">
                    Due {new Date(action.due_at).toLocaleDateString()}
                  </p>
                ) : null}
              </div>
              <div className="flex gap-3">
                <form action={setActionStatus.bind(null, action.id, "done")}>
                  <button
                    type="submit"
                    className="text-xs font-medium text-emerald-600 hover:underline dark:text-emerald-400"
                  >
                    Done
                  </button>
                </form>
                <form action={setActionStatus.bind(null, action.id, "dismissed")}>
                  <button
                    type="submit"
                    className="text-xs font-medium text-zinc-400 hover:underline dark:text-zinc-500"
                  >
                    Dismiss
                  </button>
                </form>
              </div>
            </div>
          ))
        )}
      </div>

      {done.length > 0 ? (
        <div className="flex flex-col gap-2">
          <h2 className="text-sm font-semibold text-zinc-500 dark:text-zinc-400">Recently done</h2>
          {done.map((action) => (
            <div
              key={action.id}
              className="flex items-center justify-between rounded-xl border border-zinc-100 bg-zinc-50 px-4 py-2 dark:border-zinc-900 dark:bg-zinc-950/50"
            >
              <p className="text-sm text-zinc-400 line-through dark:text-zinc-600">{action.title}</p>
              <form action={setActionStatus.bind(null, action.id, "open")}>
                <button
                  type="submit"
                  className="text-xs font-medium text-zinc-400 hover:underline dark:text-zinc-500"
                >
                  Reopen
                </button>
              </form>
            </div>
          ))}
        </div>
      ) : null}
    </div>
  );
}
