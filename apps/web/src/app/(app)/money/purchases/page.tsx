import Link from "next/link";
import type { ReturnStatus } from "@loop/contracts";
import { createClient } from "@/lib/supabase/server";
import { getActiveAccountId } from "@/lib/active-account";
import { CreatePurchaseForm } from "./create-purchase-form";
import { ReturnControls } from "./return-controls";

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

function formatCents(cents: number | null): string {
  if (cents === null) return "—";
  return (cents / 100).toLocaleString(undefined, { style: "currency", currency: "USD" });
}

export default async function PurchasesPage() {
  const accountId = await getActiveAccountId();
  const supabase = await createClient();

  const [{ data: purchases }, { data: items }, { data: returns }] = await Promise.all([
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
  ]);

  const returnByPurchase = new Map<string, ReturnRow>();
  for (const r of returns ?? []) {
    if (r.purchase_id) returnByPurchase.set(r.purchase_id, r);
  }

  return (
    <div className="flex flex-col gap-6">
      <div>
        <Link href="/money" className="text-xs text-zinc-500 hover:underline dark:text-zinc-400">
          ← Money
        </Link>
        <h1 className="mt-1 text-xl font-semibold text-zinc-950 dark:text-zinc-50">Purchases</h1>
        <p className="mt-1 text-sm text-zinc-500 dark:text-zinc-400">
          PROTECT / ReturnGuard. Record what you bought, then start a return or claim a warranty
          before the window closes.
        </p>
      </div>

      <div className="rounded-2xl border border-zinc-200 bg-white p-4 dark:border-zinc-800 dark:bg-zinc-950">
        <CreatePurchaseForm items={items ?? []} />
      </div>

      <ul className="flex flex-col gap-2">
        {(purchases ?? []).length === 0 ? (
          <p className="text-sm text-zinc-500 dark:text-zinc-400">No purchases yet.</p>
        ) : (
          (purchases ?? []).map((purchase) => (
            <li
              key={purchase.id}
              className="flex flex-col gap-2 rounded-xl border border-zinc-200 bg-white px-4 py-3 dark:border-zinc-800 dark:bg-zinc-950"
            >
              <div className="flex items-center justify-between">
                <div>
                  <p className="text-sm font-medium text-zinc-950 dark:text-zinc-50">
                    {purchase.items?.name ?? purchase.vendor_name ?? "Purchase"} · {formatCents(purchase.price_cents)}
                  </p>
                  <p className="text-xs text-zinc-500 dark:text-zinc-400">
                    {purchase.vendor_name ?? "Unknown vendor"}
                    {purchase.return_window_expires_at
                      ? ` · Return by ${new Date(purchase.return_window_expires_at).toLocaleDateString()}`
                      : ""}
                    {purchase.warranty_expires_at
                      ? ` · Warranty until ${new Date(purchase.warranty_expires_at).toLocaleDateString()}`
                      : ""}
                  </p>
                </div>
              </div>
              <ReturnControls
                purchaseId={purchase.id}
                itemId={purchase.item_id}
                existingReturn={returnByPurchase.get(purchase.id) ?? null}
              />
            </li>
          ))
        )}
      </ul>
    </div>
  );
}
