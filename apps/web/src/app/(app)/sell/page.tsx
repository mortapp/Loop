import type { Item, ItemStatus } from "@loop/contracts";
import { createClient } from "@/lib/supabase/server";
import { getActiveAccountId } from "@/lib/active-account";
import { CreateItemForm } from "./create-item-form";
import { ValuationForm, ListingForm, SaleForm } from "./item-actions";

type ValuationRow = { item_id: string; estimated_value_cents: number; valued_at: string };
type ListingRow = {
  id: string;
  item_id: string;
  marketplace: string;
  status: string;
  list_price_cents: number | null;
};

const STATUS_STYLES: Record<ItemStatus, string> = {
  owned: "bg-zinc-100 text-zinc-600 dark:bg-zinc-900 dark:text-zinc-400",
  returned: "bg-amber-100 text-amber-700 dark:bg-amber-950 dark:text-amber-400",
  listed: "bg-blue-100 text-blue-700 dark:bg-blue-950 dark:text-blue-400",
  sold: "bg-emerald-100 text-emerald-700 dark:bg-emerald-950 dark:text-emerald-400",
  disposed: "bg-zinc-100 text-zinc-400 dark:bg-zinc-900 dark:text-zinc-600",
};

function formatCents(cents: number | null): string {
  if (cents === null) return "—";
  return (cents / 100).toLocaleString(undefined, { style: "currency", currency: "USD" });
}

export default async function SellPage() {
  const accountId = await getActiveAccountId();
  const supabase = await createClient();

  const [{ data: items }, { data: valuations }, { data: listings }] = await Promise.all([
    accountId
      ? supabase
          .from("items")
          .select("*")
          .eq("account_id", accountId)
          .order("created_at", { ascending: false })
          .returns<Item[]>()
      : Promise.resolve({ data: [] as Item[] }),
    accountId
      ? supabase
          .from("valuations")
          .select("item_id, estimated_value_cents, valued_at")
          .eq("account_id", accountId)
          .order("valued_at", { ascending: false })
          .returns<ValuationRow[]>()
      : Promise.resolve({ data: [] as ValuationRow[] }),
    accountId
      ? supabase
          .from("listings")
          .select("id, item_id, marketplace, status, list_price_cents")
          .eq("account_id", accountId)
          .in("status", ["draft", "active"])
          .returns<ListingRow[]>()
      : Promise.resolve({ data: [] as ListingRow[] }),
  ]);

  const latestValuationByItem = new Map<string, ValuationRow>();
  for (const v of valuations ?? []) {
    if (!latestValuationByItem.has(v.item_id)) {
      latestValuationByItem.set(v.item_id, v);
    }
  }
  const listingsByItem = new Map<string, ListingRow[]>();
  for (const l of listings ?? []) {
    listingsByItem.set(l.item_id, [...(listingsByItem.get(l.item_id) ?? []), l]);
  }

  return (
    <div className="flex flex-col gap-6">
      <div>
        <h1 className="text-xl font-semibold text-zinc-950 dark:text-zinc-50">Sell</h1>
        <p className="mt-1 text-sm text-zinc-500 dark:text-zinc-400">
          RECOVER / ResellLens. Value an item, list it, then record the sale — a completed sale
          posts straight to Money as recovered value.
        </p>
      </div>

      <div className="rounded-2xl border border-zinc-200 bg-white p-4 dark:border-zinc-800 dark:bg-zinc-950">
        <CreateItemForm />
      </div>

      <ul className="flex flex-col gap-2">
        {(items ?? []).length === 0 ? (
          <p className="text-sm text-zinc-500 dark:text-zinc-400">No items yet.</p>
        ) : (
          (items ?? []).map((item) => {
            const valuation = latestValuationByItem.get(item.id);
            const itemListings = listingsByItem.get(item.id) ?? [];
            return (
              <li
                key={item.id}
                className="flex flex-col gap-2 rounded-xl border border-zinc-200 bg-white px-4 py-3 dark:border-zinc-800 dark:bg-zinc-950"
              >
                <div className="flex items-center justify-between">
                  <div>
                    <p className="text-sm font-medium text-zinc-950 dark:text-zinc-50">{item.name}</p>
                    <p className="text-xs text-zinc-500 dark:text-zinc-400">
                      {[item.category, item.condition].filter(Boolean).join(" · ") || "No details"}
                      {valuation ? ` · Valued at ${formatCents(valuation.estimated_value_cents)}` : ""}
                    </p>
                  </div>
                  <span className={`rounded-full px-2 py-0.5 text-xs font-medium ${STATUS_STYLES[item.status]}`}>
                    {item.status}
                  </span>
                </div>

                {itemListings.length > 0 ? (
                  <div className="flex flex-col gap-1">
                    {itemListings.map((listing) => (
                      <p key={listing.id} className="text-xs text-zinc-500 dark:text-zinc-400">
                        Listed on {listing.marketplace}
                        {listing.list_price_cents ? ` for ${formatCents(listing.list_price_cents)}` : ""} ·{" "}
                        {listing.status}
                      </p>
                    ))}
                  </div>
                ) : null}

                {item.status !== "sold" ? (
                  <div className="flex flex-wrap items-center gap-4">
                    <ValuationForm itemId={item.id} />
                    {item.status !== "listed" ? <ListingForm itemId={item.id} /> : null}
                    <SaleForm itemId={item.id} listingId={itemListings[0]?.id} />
                  </div>
                ) : null}
              </li>
            );
          })
        )}
      </ul>
    </div>
  );
}
