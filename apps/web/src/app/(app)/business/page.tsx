import Link from "next/link";
import { createClient } from "@/lib/supabase/server";
import { getActiveAccountId } from "@/lib/active-account";
import { CreateBusinessForm } from "./create-business-form";
import { switchActiveAccount } from "./actions";

type AccountRow = {
  id: string;
  type: "personal" | "business";
  businesses: { id: string; name: string; slug: string } | null;
};

export default async function BusinessPage() {
  const supabase = await createClient();
  const [{ data: accounts }, activeAccountId] = await Promise.all([
    supabase.from("accounts").select("id, type, businesses(id, name, slug)").returns<AccountRow[]>(),
    getActiveAccountId(),
  ]);

  return (
    <div className="flex flex-col gap-6">
      <div>
        <h1 className="text-xl font-semibold text-zinc-950 dark:text-zinc-50">Business</h1>
        <p className="mt-1 text-sm text-zinc-500 dark:text-zinc-400">
          Every account you can act as — your personal account, plus any business you belong to.
          The active one is what Today, Money, and Sell show data for.
        </p>
      </div>

      <ul className="flex flex-col gap-2">
        {(accounts ?? []).map((account) => {
          const isActive = account.id === activeAccountId;
          return (
            <li
              key={account.id}
              className="flex items-center justify-between rounded-xl border border-zinc-200 bg-white px-4 py-3 dark:border-zinc-800 dark:bg-zinc-950"
            >
              <div>
                <p className="text-sm font-medium text-zinc-950 dark:text-zinc-50">
                  {account.type === "personal" ? "Personal account" : account.businesses?.name}
                </p>
                <p className="text-xs text-zinc-500 dark:text-zinc-400">
                  {account.type === "personal" ? "Just you" : `@${account.businesses?.slug}`}
                </p>
              </div>
              <div className="flex items-center gap-3">
                <span className="rounded-full bg-zinc-100 px-2 py-0.5 text-xs font-medium text-zinc-600 dark:bg-zinc-900 dark:text-zinc-400">
                  {account.type}
                </span>
                {isActive ? (
                  <span className="text-xs font-medium text-emerald-600 dark:text-emerald-400">
                    Active
                  </span>
                ) : (
                  <form action={switchActiveAccount}>
                    <input type="hidden" name="accountId" value={account.id} />
                    <button
                      type="submit"
                      className="text-xs font-medium text-zinc-500 underline hover:text-zinc-950 dark:text-zinc-400 dark:hover:text-zinc-50"
                    >
                      Switch to this
                    </button>
                  </form>
                )}
              </div>
            </li>
          );
        })}
      </ul>

      <div className="grid grid-cols-2 gap-3">
        <Link
          href="/business/contacts"
          className="rounded-2xl border border-zinc-200 bg-white p-4 hover:border-zinc-300 dark:border-zinc-800 dark:bg-zinc-950 dark:hover:border-zinc-700"
        >
          <p className="text-sm font-semibold text-zinc-950 dark:text-zinc-50">Contacts</p>
          <p className="mt-1 text-xs text-zinc-500 dark:text-zinc-400">
            Customers, vendors, and anyone else you deal with.
          </p>
        </Link>
        <Link
          href="/business/leads"
          className="rounded-2xl border border-zinc-200 bg-white p-4 hover:border-zinc-300 dark:border-zinc-800 dark:bg-zinc-950 dark:hover:border-zinc-700"
        >
          <p className="text-sm font-semibold text-zinc-950 dark:text-zinc-50">Leads</p>
          <p className="mt-1 text-xs text-zinc-500 dark:text-zinc-400">
            MAKE / QuoteCloser — track interest before it&apos;s worth quoting.
          </p>
        </Link>
      </div>

      <div className="rounded-2xl border border-zinc-200 bg-white p-4 dark:border-zinc-800 dark:bg-zinc-950">
        <h2 className="mb-3 text-sm font-semibold text-zinc-950 dark:text-zinc-50">
          Start a business
        </h2>
        <CreateBusinessForm />
      </div>
    </div>
  );
}
