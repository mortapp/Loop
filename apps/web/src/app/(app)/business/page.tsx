import { createClient } from "@/lib/supabase/server";
import { CreateBusinessForm } from "./create-business-form";

type AccountRow = {
  id: string;
  type: "personal" | "business";
  businesses: { id: string; name: string; slug: string } | null;
};

export default async function BusinessPage() {
  const supabase = await createClient();
  const { data: accounts } = await supabase
    .from("accounts")
    .select("id, type, businesses(id, name, slug)")
    .returns<AccountRow[]>();

  return (
    <div className="flex flex-col gap-6">
      <div>
        <h1 className="text-xl font-semibold text-zinc-950 dark:text-zinc-50">Business</h1>
        <p className="mt-1 text-sm text-zinc-500 dark:text-zinc-400">
          Every account you can act as — your personal account, plus any business you belong to.
        </p>
      </div>

      <ul className="flex flex-col gap-2">
        {(accounts ?? []).map((account) => (
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
            <span className="rounded-full bg-zinc-100 px-2 py-0.5 text-xs font-medium text-zinc-600 dark:bg-zinc-900 dark:text-zinc-400">
              {account.type}
            </span>
          </li>
        ))}
      </ul>

      <div className="rounded-2xl border border-zinc-200 bg-white p-4 dark:border-zinc-800 dark:bg-zinc-950">
        <h2 className="mb-3 text-sm font-semibold text-zinc-950 dark:text-zinc-50">
          Start a business
        </h2>
        <CreateBusinessForm />
      </div>
    </div>
  );
}
