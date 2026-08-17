"use server";

import { revalidatePath } from "next/cache";
import { createClient } from "@/lib/supabase/server";
import { getActiveAccountId } from "@/lib/active-account";

export type FormState = { error: string } | null;

export async function createPurchase(_prev: FormState, formData: FormData): Promise<FormState> {
  const itemId = String(formData.get("itemId") ?? "").trim() || null;
  const vendorName = String(formData.get("vendorName") ?? "").trim() || null;
  const purchaseDate = String(formData.get("purchaseDate") ?? "").trim() || null;
  const price = String(formData.get("price") ?? "").trim();
  const returnWindowExpiresAt = String(formData.get("returnWindowExpiresAt") ?? "").trim() || null;
  const warrantyExpiresAt = String(formData.get("warrantyExpiresAt") ?? "").trim() || null;

  const priceCents = price ? Math.round(Number(price) * 100) : null;
  if (price && !Number.isFinite(priceCents)) {
    return { error: "Price must be a number." };
  }

  const accountId = await getActiveAccountId();
  if (!accountId) {
    return { error: "No active account." };
  }

  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  const { error } = await supabase.from("purchases").insert({
    account_id: accountId,
    item_id: itemId,
    vendor_name: vendorName,
    purchase_date: purchaseDate,
    price_cents: priceCents,
    return_window_expires_at: returnWindowExpiresAt,
    warranty_expires_at: warrantyExpiresAt,
    created_by: user?.id ?? null,
  });

  if (error) {
    return { error: error.message };
  }

  if (priceCents) {
    await supabase.from("money_events").insert({
      account_id: accountId,
      item_id: itemId,
      kind: "spend",
      amount_cents: priceCents,
      source_type: "purchase",
      description: vendorName ? `Purchase from ${vendorName}` : "Purchase",
      created_by: user?.id ?? null,
    });
  }

  revalidatePath("/money/purchases");
  revalidatePath("/money");
  return null;
}

export async function startReturn(_prev: FormState, formData: FormData): Promise<FormState> {
  const purchaseId = String(formData.get("purchaseId") ?? "").trim();
  const itemId = String(formData.get("itemId") ?? "").trim();
  const reason = String(formData.get("reason") ?? "").trim() || null;

  if (!itemId) {
    return { error: "This purchase has no linked item — returns need one." };
  }

  const accountId = await getActiveAccountId();
  if (!accountId) {
    return { error: "No active account." };
  }

  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  const { error } = await supabase.from("returns").insert({
    account_id: accountId,
    item_id: itemId,
    purchase_id: purchaseId || null,
    reason,
    created_by: user?.id ?? null,
  });

  if (error) {
    return { error: error.message };
  }

  revalidatePath("/money/purchases");
  return null;
}

export async function setReturnStatus(
  id: string,
  status: "initiated" | "shipped" | "received" | "denied",
) {
  const supabase = await createClient();
  const patch: Record<string, unknown> = { status };
  if (status === "denied") {
    patch.resolved_at = new Date().toISOString();
  }
  await supabase.from("returns").update(patch).eq("id", id);
  revalidatePath("/money/purchases");
}

export async function refundReturn(_prev: FormState, formData: FormData): Promise<FormState> {
  const returnId = String(formData.get("returnId") ?? "").trim();
  const itemId = String(formData.get("itemId") ?? "").trim();
  const amount = String(formData.get("amount") ?? "").trim();
  const refundAmountCents = Math.round(Number(amount) * 100);

  if (!returnId || !itemId || !amount || !Number.isFinite(refundAmountCents) || refundAmountCents <= 0) {
    return { error: "Enter a valid refund amount." };
  }

  const accountId = await getActiveAccountId();
  if (!accountId) {
    return { error: "No active account." };
  }

  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  await supabase
    .from("returns")
    .update({
      status: "refunded",
      refund_amount_cents: refundAmountCents,
      resolved_at: new Date().toISOString(),
    })
    .eq("id", returnId);

  await supabase.from("money_events").insert({
    account_id: accountId,
    item_id: itemId,
    kind: "refund",
    amount_cents: refundAmountCents,
    source_type: "return",
    description: "Return refunded",
    created_by: user?.id ?? null,
  });

  await supabase.from("items").update({ status: "returned" }).eq("id", itemId);

  revalidatePath("/money/purchases");
  revalidatePath("/money");
  return null;
}

export async function addWarranty(_prev: FormState, formData: FormData): Promise<FormState> {
  const itemId = String(formData.get("itemId") ?? "").trim();
  const provider = String(formData.get("provider") ?? "").trim() || null;
  const expiresAt = String(formData.get("expiresAt") ?? "").trim() || null;

  if (!itemId) {
    return { error: "This purchase has no linked item — warranties need one." };
  }

  const accountId = await getActiveAccountId();
  if (!accountId) {
    return { error: "No active account." };
  }

  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  const { error } = await supabase.from("warranties").insert({
    account_id: accountId,
    item_id: itemId,
    provider,
    expires_at: expiresAt,
    created_by: user?.id ?? null,
  });

  if (error) {
    return { error: error.message };
  }

  revalidatePath("/money/purchases");
  return null;
}

export async function setWarrantyClaimStatus(id: string, claimStatus: string) {
  const supabase = await createClient();
  await supabase.from("warranties").update({ claim_status: claimStatus }).eq("id", id);
  revalidatePath("/money/purchases");
}
