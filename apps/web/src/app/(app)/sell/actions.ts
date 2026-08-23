"use server";

import { revalidatePath } from "next/cache";
import { createClient } from "@/lib/supabase/server";
import { getActiveAccountId } from "@/lib/active-account";
import { userSafeServerError } from "@/lib/user-safe-error";

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

  if (
    purchasePriceCents !== null &&
    (!Number.isFinite(purchasePriceCents) || purchasePriceCents < 0)
  ) {
    return { error: "Enter a valid purchase price." };
  }

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
    return { error: userSafeServerError("sell:create-item", error) };
  }

  revalidatePath("/sell");
  return null;
}

/**
 * Records a photo that was already uploaded client-side (the upload itself
 * happens directly against Supabase Storage from the browser -- see
 * `AddPhotoControl` in `item-actions.tsx` -- because streaming a file
 * through a Server Action isn't the right tool for that; this just appends
 * the resulting object path to `items.photos` under RLS). `objectPath` is
 * always `<accountId>/<itemId>/<uuid>.<ext>`, written by the same account
 * member the storage policy already authorized for that upload.
 */
export async function attachItemPhoto(itemId: string, objectPath: string): Promise<FormState> {
  const supabase = await createClient();
  const { data: item, error: fetchError } = await supabase
    .from("items")
    .select("photos")
    .eq("id", itemId)
    .single();
  if (fetchError) {
    return { error: userSafeServerError("sell:load-item-photos", fetchError) };
  }

  const photos = [...((item?.photos as string[] | null) ?? []), objectPath];
  const { error } = await supabase.from("items").update({ photos }).eq("id", itemId);
  if (error) {
    return { error: userSafeServerError("sell:add-item-photo", error) };
  }

  revalidatePath("/sell");
  return null;
}

export async function removeItemPhoto(itemId: string, objectPath: string) {
  const supabase = await createClient();
  const { data: item } = await supabase.from("items").select("photos").eq("id", itemId).single();
  const photos = ((item?.photos as string[] | null) ?? []).filter((p) => p !== objectPath);

  await supabase.from("items").update({ photos }).eq("id", itemId);
  await supabase.storage.from("item-photos").remove([objectPath]);

  revalidatePath("/sell");
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
    return { error: userSafeServerError("sell:create-valuation", error) };
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
  if (listPriceCents !== null && (!Number.isFinite(listPriceCents) || listPriceCents < 0)) {
    return { error: "Enter a valid listing price." };
  }

  const accountId = await getActiveAccountId();
  if (!accountId) {
    return { error: "No active account." };
  }

  const supabase = await createClient();
  const { error } = await supabase.rpc("create_listing_and_mark_item", {
    p_account_id: accountId,
    p_item_id: itemId,
    p_marketplace: marketplace,
    p_list_price_cents: listPriceCents,
  });

  if (error) {
    return { error: "Could not create this listing. Please try again." };
  }

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

  if (
    !itemId ||
    !Number.isFinite(salePriceCents) ||
    salePriceCents <= 0 ||
    !Number.isFinite(feesCents) ||
    feesCents < 0 ||
    feesCents > salePriceCents
  ) {
    return { error: "Enter a valid sale price." };
  }

  const accountId = await getActiveAccountId();
  if (!accountId) {
    return { error: "No active account." };
  }

  const supabase = await createClient();
  const { error: saleError } = await supabase.rpc("record_item_sale", {
    p_account_id: accountId,
    p_item_id: itemId,
    p_listing_id: listingId,
    p_sale_price_cents: salePriceCents,
    p_fees_cents: feesCents,
  });

  if (saleError) {
    return { error: "Could not record this sale. Please try again." };
  }

  revalidatePath("/sell");
  revalidatePath("/money");
  return null;
}
