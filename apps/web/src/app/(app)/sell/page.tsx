import type { Item, ItemStatus } from "@loop/contracts";
import { createClient } from "@/lib/supabase/server";
import { getActiveAccountId } from "@/lib/active-account";
import { Amount } from "@/components/ui/amount";
import { Card } from "@/components/ui/card";
import { EmptyState } from "@/components/ui/empty-state";
import { StatusBadge } from "@/components/ui/status-badge";
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

const STATUS_TONE: Record<ItemStatus, "neutral" | "info" | "brand" | "opportunity"> = {
  owned: "neutral",
  returned: "opportunity",
  listed: "info",
  sold: "brand",
  disposed: "neutral",
};

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
      <h1 className="text-xl font-semibold text-[var(--color-text-primary)]">Sell</h1>

      <Card className="p-4">
        <CreateItemForm />
      </Card>

      <div className="flex flex-col gap-2">
        {(items ?? []).length === 0 ? (
          <EmptyState
            title="No items ready to recover value from yet"
            description="Add an item above, then value it and list it when you're ready to sell."
          />
        ) : (
          (items ?? []).map((item) => {
            const valuation = latestValuationByItem.get(item.id);
            const itemListings = listingsByItem.get(item.id) ?? [];
            return (
              <Card key={item.id} className="flex flex-col gap-3 px-4 py-3">
                <div className="flex items-start justify-between gap-2">
                  <div>
                    <p className="text-sm font-medium text-[var(--color-text-primary)]">{item.name}</p>
                    <p className="text-xs text-[var(--color-text-tertiary)]">
                      {[item.category, item.condition].filter(Boolean).join(" · ") || "No details"}
                    </p>
                    {valuation ? (
                      <p className="mt-1 flex items-center gap-1 text-xs text-[var(--color-text-tertiary)]">
                        Est. value
                        <Amount cents={valuation.estimated_value_cents} tone="opportunity" className="text-xs" />
                      </p>
                    ) : null}
                  </div>
                  <StatusBadge label={item.status} tone={STATUS_TONE[item.status]} />
                </div>

                {itemListings.length > 0 ? (
                  <div className="flex flex-col gap-1">
                    {itemListings.map((listing) => (
                      <p key={listing.id} className="text-xs text-[var(--color-text-tertiary)]">
                        Listed on {listing.marketplace}
                        {listing.list_price_cents ? (
                          <>
                            {" for "}
                            <Amount cents={listing.list_price_cents} className="text-xs" />
                          </>
                        ) : null}{" "}
                        · {listing.status}
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
              </Card>
            );
          })
        )}
      </div>
    </div>
  );
}
