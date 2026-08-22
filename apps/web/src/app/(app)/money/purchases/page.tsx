import Link from "next/link";
import type { ReturnStatus } from "@loop/contracts";
import { createClient } from "@/lib/supabase/server";
import { getActiveAccountId } from "@/lib/active-account";
import { Amount } from "@/components/ui/amount";
import { Card } from "@/components/ui/card";
import { EmptyState } from "@/components/ui/empty-state";
import { StatusBadge } from "@/components/ui/status-badge";
import { CreatePurchaseForm } from "./create-purchase-form";
import { ReturnControls } from "./return-controls";
import { WarrantyControls } from "./warranty-controls";

type PurchaseRow = {
  id: string;
  item_id: string | null;
  vendor_name: string | null;
  purchase_date: string | null;
  price_cents: number | null;
  return_window_expires_at: string | null;
  warranty_expires_at: string | null;
  items: { id: string; name: string } | null;
};

type ReturnRow = { id: string; purchase_id: string | null; status: ReturnStatus };
type WarrantyRow = {
  id: string;
  item_id: string;
  provider: string | null;
  expires_at: string | null;
  claim_status: string | null;
};

/** Real "N days left" urgency, calculated from the actual deadline — not
    a fake countdown. Part 11 of the design brief: clear urgency without
    fake scarcity. */
function returnWindowBadge(expiresAt: string) {
  const days = Math.ceil((new Date(expiresAt).getTime() - Date.now()) / 86_400_000);
  if (days < 0) return <StatusBadge label="Window closed" tone="neutral" />;
  if (days === 0) return <StatusBadge label="Return today" tone="danger" />;
  if (days <= 3) return <StatusBadge label={`${days} day${days === 1 ? "" : "s"} left`} tone="danger" />;
  if (days <= 14) return <StatusBadge label={`${days} days left`} tone="opportunity" />;
  return <StatusBadge label={`Return by ${new Date(expiresAt).toLocaleDateString(undefined, { month: "short", day: "numeric" })}`} tone="neutral" />;
}

export default async function PurchasesPage() {
  const accountId = await getActiveAccountId();
  const supabase = await createClient();

  const [{ data: purchases }, { data: items }, { data: returns }, { data: warranties }] = await Promise.all([
    accountId
      ? supabase
          .from("purchases")
          .select(
            "id, item_id, vendor_name, purchase_date, price_cents, return_window_expires_at, warranty_expires_at, items(id, name)",
          )
          .eq("account_id", accountId)
          .order("created_at", { ascending: false })
          .returns<PurchaseRow[]>()
      : Promise.resolve({ data: [] as PurchaseRow[] }),
    accountId
      ? supabase.from("items").select("id, name").eq("account_id", accountId).order("name", { ascending: true })
      : Promise.resolve({ data: [] as { id: string; name: string }[] }),
    accountId
      ? supabase.from("returns").select("id, purchase_id, status").eq("account_id", accountId).returns<ReturnRow[]>()
      : Promise.resolve({ data: [] as ReturnRow[] }),
    accountId
      ? supabase
          .from("warranties")
          .select("id, item_id, provider, expires_at, claim_status")
          .eq("account_id", accountId)
          .returns<WarrantyRow[]>()
      : Promise.resolve({ data: [] as WarrantyRow[] }),
  ]);

  const returnByPurchase = new Map<string, ReturnRow>();
  for (const r of returns ?? []) {
    if (r.purchase_id) returnByPurchase.set(r.purchase_id, r);
  }

  const warrantiesByItem = new Map<string, WarrantyRow[]>();
  for (const w of warranties ?? []) {
    warrantiesByItem.set(w.item_id, [...(warrantiesByItem.get(w.item_id) ?? []), w]);
  }

  return (
    <div className="flex flex-col gap-6">
      <div>
        <Link href="/money" className="text-xs text-[var(--color-text-tertiary)] hover:underline">
          ← Money
        </Link>
        <h1 className="mt-1 text-xl font-semibold text-[var(--color-text-primary)]">Purchases</h1>
      </div>

      <Card className="p-4">
        <CreatePurchaseForm items={items ?? []} />
      </Card>

      <div className="flex flex-col gap-2">
        {(purchases ?? []).length === 0 ? (
          <EmptyState
            title="No purchases tracked yet"
            description="Record what you buy to track return windows and warranties before they expire."
          />
        ) : (
          (purchases ?? []).map((purchase) => (
            <Card key={purchase.id} className="flex flex-col gap-3 px-4 py-3">
              <div className="flex flex-wrap items-start justify-between gap-2">
                <div>
                  <p className="text-sm font-medium text-[var(--color-text-primary)]">
                    {purchase.items?.name ?? purchase.vendor_name ?? "Purchase"}
                  </p>
                  <p className="text-xs text-[var(--color-text-tertiary)]">
                    {purchase.vendor_name ?? "Unknown vendor"}
                    {purchase.price_cents !== null ? (
                      <>
                        {" · "}
                        <Amount cents={purchase.price_cents} className="text-xs" />
                      </>
                    ) : null}
                    {purchase.warranty_expires_at
                      ? ` · Warranty until ${new Date(purchase.warranty_expires_at).toLocaleDateString()}`
                      : ""}
                  </p>
                </div>
                {purchase.return_window_expires_at ? returnWindowBadge(purchase.return_window_expires_at) : null}
              </div>
              <ReturnControls
                purchaseId={purchase.id}
                itemId={purchase.item_id}
                existingReturn={returnByPurchase.get(purchase.id) ?? null}
              />
              <WarrantyControls
                itemId={purchase.item_id}
                warranties={purchase.item_id ? (warrantiesByItem.get(purchase.item_id) ?? []) : []}
              />
            </Card>
          ))
        )}
      </div>
    </div>
  );
}
