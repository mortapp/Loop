import type { Item, ItemStatus } from "@loop/contracts";
import { createClient } from "@/lib/supabase/server";
import { getActiveAccountId } from "@/lib/active-account";
import { Amount } from "@/components/ui/amount";
import { Card } from "@/components/ui/card";
import { EmptyState } from "@/components/ui/empty-state";
import { StatusBadge } from "@/components/ui/status-badge";
import { LoopSeal } from "@/components/ui/loop-seal";
import { CreateItemForm } from "./create-item-form";
import { ValuationForm, ListingForm, SaleForm, AddPhotoControl } from "./item-actions";
import { removeItemPhoto } from "./actions";

const SIGNED_URL_TTL_SECONDS = 60 * 60; // 1 hour -- regenerated on every render

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

  // The bucket is private -- every photo path becomes a short-lived signed
  // URL at render time rather than a public/permanent one.
  const allPhotoPaths = (items ?? []).flatMap((item) => item.photos ?? []);
  const signedUrlByPath = new Map<string, string>();
  if (allPhotoPaths.length > 0) {
    const { data: signed } = await supabase.storage
      .from("item-photos")
      .createSignedUrls(allPhotoPaths, SIGNED_URL_TTL_SECONDS);
    for (const entry of signed ?? []) {
      if (entry.signedUrl) signedUrlByPath.set(entry.path ?? "", entry.signedUrl);
    }
  }

  return (
    <div className="flex flex-col gap-6">
      <h1 className="text-xl font-semibold text-[var(--color-text-primary)]">Sell</h1>

      <Card className="p-4">
        <CreateItemForm />
      </Card>

      {(items ?? []).length === 0 ? (
        <EmptyState
          title="No items ready to recover value from yet"
          description="Add an item above, then value it and list it when you're ready to sell."
        />
      ) : (
        // A private collection, not a marketplace feed — one column on
        // phones, an editorial grid from tablet up. Image carries the
        // tile; chrome stays minimal.
        <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-3">
          {(items ?? []).map((item) => {
            const valuation = latestValuationByItem.get(item.id);
            const itemListings = listingsByItem.get(item.id) ?? [];
            const photoPaths = item.photos ?? [];
            const heroUrl = photoPaths[0] ? signedUrlByPath.get(photoPaths[0]) : undefined;
            return (
              <Card key={item.id} className="flex flex-col gap-3 overflow-hidden p-0">
                <div className="relative flex aspect-[4/3] items-center justify-center bg-[var(--color-bg-secondary)]">
                  {heroUrl ? (
                    // eslint-disable-next-line @next/next/no-img-element -- item photos are signed Storage URLs (expire hourly), not build-time assets next/image can cache
                    <img src={heroUrl} alt={item.name} className="h-full w-full object-cover" />
                  ) : (
                    <LoopSeal size={44} className="opacity-20" />
                  )}
                  <div className="absolute right-2 top-2">
                    <StatusBadge label={item.status} tone={STATUS_TONE[item.status]} />
                  </div>
                </div>

                {photoPaths.length > 1 ? (
                  <div className="flex gap-1.5 overflow-x-auto px-4">
                    {photoPaths.slice(1).map((path) => {
                      const url = signedUrlByPath.get(path);
                      if (!url) return null;
                      return (
                        <div key={path} className="group relative h-12 w-12 shrink-0">
                          {/* eslint-disable-next-line @next/next/no-img-element -- signed Storage URL thumbnail */}
                          <img
                            src={url}
                            alt=""
                            className="h-full w-full rounded-[var(--radius-sm)] object-cover"
                          />
                          {item.status !== "sold" ? (
                            <form
                              action={removeItemPhoto.bind(null, item.id, path)}
                              className="absolute -right-1 -top-1"
                            >
                              <button
                                type="submit"
                                aria-label="Remove photo"
                                className="flex h-4 w-4 items-center justify-center rounded-full bg-[var(--color-danger)] text-[9px] text-[var(--color-on-accent)] opacity-0 transition-opacity group-hover:opacity-100"
                              >
                                ×
                              </button>
                            </form>
                          ) : null}
                        </div>
                      );
                    })}
                  </div>
                ) : null}

                <div className="flex flex-1 flex-col gap-3 px-4 pb-4">
                  <div>
                    <p className="text-sm font-medium text-[var(--color-text-primary)]">{item.name}</p>
                    <p className="text-xs text-[var(--color-text-tertiary)]">
                      {[item.category, item.condition].filter(Boolean).join(" · ") || "No details"}
                    </p>
                    {valuation ? (
                      <p className="mt-2 flex items-baseline gap-1.5">
                        <span className="text-[10px] font-semibold tracking-[0.1em] text-[var(--color-text-tertiary)]">
                          EST. VALUE
                        </span>
                        <Amount cents={valuation.estimated_value_cents} tone="opportunity" className="text-sm font-medium" />
                      </p>
                    ) : null}
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
                    <div className="mt-auto flex flex-wrap items-center gap-4 border-t border-[var(--color-border-subtle)] pt-3">
                      <AddPhotoControl itemId={item.id} accountId={item.account_id} />
                      <ValuationForm itemId={item.id} />
                      {item.status !== "listed" ? <ListingForm itemId={item.id} /> : null}
                      <SaleForm itemId={item.id} listingId={itemListings[0]?.id} />
                    </div>
                  ) : null}
                </div>
              </Card>
            );
          })}
        </div>
      )}
    </div>
  );
}
