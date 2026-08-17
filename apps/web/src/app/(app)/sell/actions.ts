"use server";

import { revalidatePath } from "next/cache";
import { createClient } from "@/lib/supabase/server";
import { getActiveAccountId } from "@/lib/active-account";

export type FormState = { error: string } | null;

export async function createItem(_prev: FormState, formData: FormData): Promise<FormState> {
  const name = String(formData.get("name") ?? "").trim();
  if (!name) {
    return { error: "Name is required." };
  }

  const category = String(formData.get("category") ?? "").trim() || null;
  const condition = String(formData.get("condition") ?? "").trim() || null;
  const purchasePrice = String(formData.get("purchasePrice") ?? "").trim();
  const purchasePriceCents = purchasePrice ? Math.round(Number(purchasePrice) * 100) : null;

  const accountId = await getActiveAccountId();
  if (!accountId) {
    return { error: "No active account." };
  }

  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  const { error } = await supabase.from("items").insert({
    account_id: accountId,
    name,
    category,
    condition,
    purchase_price_cents: purchasePriceCents,
    created_by: user?.id ?? null,
  });

  if (error) {
    return { error: error.message };
  }

  revalidatePath("/sell");
  return null;
}

export async function addValuation(_prev: FormState, formData: FormData): Promise<FormState> {
  const itemId = String(formData.get("itemId") ?? "").trim();
  const value = String(formData.get("value") ?? "").trim();
  const estimatedValueCents = Math.round(Number(value) * 100);

  if (!itemId || !value || !Number.isFinite(estimatedValueCents) || estimatedValueCents <= 0) {
    return { error: "Enter a valid estimated value." };
  }

  const accountId = await getActiveAccountId();
  if (!accountId) {
    return { error: "No active account." };
  }

  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  const { error } = await supabase.from("valuations").insert({
    account_id: accountId,
    item_id: itemId,
    source: "manual",
    estimated_value_cents: estimatedValueCents,
    created_by: user?.id ?? null,
  });

  if (error) {
    return { error: error.message };
  }

  revalidatePath("/sell");
  return null;
}

export async function createListing(_prev: FormState, formData: FormData): Promise<FormState> {
  const itemId = String(formData.get("itemId") ?? "").trim();
  const marketplace = String(formData.get("marketplace") ?? "").trim();
  const listPrice = String(formData.get("listPrice") ?? "").trim();
  const listPriceCents = listPrice ? Math.round(Number(listPrice) * 100) : null;

  if (!itemId || !marketplace) {
    return { error: "Marketplace is required." };
  }

  const accountId = await getActiveAccountId();
  if (!accountId) {
    return { error: "No active account." };
  }

  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  const { error } = await supabase.from("listings").insert({
    account_id: accountId,
    item_id: itemId,
    marketplace,
    status: "active",
    list_price_cents: listPriceCents,
    published_at: new Date().toISOString(),
    created_by: user?.id ?? null,
  });

  if (error) {
    return { error: error.message };
  }

  await supabase.from("items").update({ status: "listed" }).eq("id", itemId);

  revalidatePath("/sell");
  return null;
}

export async function recordSale(_prev: FormState, formData: FormData): Promise<FormState> {
  const itemId = String(formData.get("itemId") ?? "").trim();
  const listingId = String(formData.get("listingId") ?? "").trim() || null;
  const salePrice = String(formData.get("salePrice") ?? "").trim();
  const fees = String(formData.get("fees") ?? "").trim();

  const salePriceCents = Math.round(Number(salePrice) * 100);
  const feesCents = fees ? Math.round(Number(fees) * 100) : 0;

  if (!itemId || !Number.isFinite(salePriceCents) || salePriceCents <= 0) {
    return { error: "Enter a valid sale price." };
  }

  const accountId = await getActiveAccountId();
  if (!accountId) {
    return { error: "No active account." };
  }

  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  const netAmountCents = salePriceCents - feesCents;

  const { error: saleError } = await supabase.from("sales").insert({
    account_id: accountId,
    item_id: itemId,
    listing_id: listingId,
    sale_price_cents: salePriceCents,
    fees_cents: feesCents,
    net_amount_cents: netAmountCents,
    created_by: user?.id ?? null,
  });

  if (saleError) {
    return { error: saleError.message };
  }

  await supabase.from("items").update({ status: "sold" }).eq("id", itemId);
  if (listingId) {
    await supabase.from("listings").update({ status: "sold" }).eq("id", listingId);
  }

  await supabase.from("money_events").insert({
    account_id: accountId,
    item_id: itemId,
    kind: "recovered",
    amount_cents: netAmountCents,
    source_type: "sale",
    description: "Item sold via RECOVER",
    created_by: user?.id ?? null,
  });

  revalidatePath("/sell");
  revalidatePath("/money");
  return null;
}
