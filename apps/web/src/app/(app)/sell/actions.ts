"use server";

import { revalidatePath } from "next/cache";
import { createClient } from "@/lib/supabase/server";
import { getActiveAccountId } from "@/lib/active-account";
import { parseDollarsToCents } from "@/lib/money-input";
import { userSafeServerError } from "@/lib/user-safe-error";
import type { ActionResult } from "@/lib/action-result";

export type FormState = { error: string } | null;

export async function createItem(_prev: FormState, formData: FormData): Promise<FormState> {
  const name = String(formData.get("name") ?? "").trim();
  if (!name) {
    return { error: "Name is required." };
  }

  const category = String(formData.get("category") ?? "").trim() || null;
  const condition = String(formData.get("condition") ?? "").trim() || null;
  const purchasePrice = String(formData.get("purchasePrice") ?? "").trim();
  const purchasePriceCents = purchasePrice
    ? parseDollarsToCents(purchasePrice, { allowZero: true })
    : null;

  if (purchasePriceCents !== null && purchasePriceCents === null) {
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
 * always `<accountId>/<itemId>/<uuid>.<ext>`. The RPC validates the account,
 * item, path, and Storage object, then appends under a row lock so concurrent
 * uploads cannot overwrite each other.
 */
export async function attachItemPhoto(itemId: string, objectPath: string): Promise<FormState> {
  const accountId = await getActiveAccountId();
  if (!accountId) {
    return { error: "No active account." };
  }
  if (!itemId || !objectPath.startsWith(`${accountId}/${itemId}/`)) {
    return { error: "That photo upload is not valid." };
  }

  const supabase = await createClient();
  const { error } = await supabase.rpc("attach_item_photo", {
    p_account_id: accountId,
    p_item_id: itemId,
    p_object_path: objectPath,
  });
  if (error) {
    return { error: userSafeServerError("sell:add-item-photo", error) };
  }

  revalidatePath("/sell");
  return null;
}

export async function removeItemPhoto(
  itemId: string,
  objectPath: string,
  _previousState: ActionResult,
  _formData: FormData,
): Promise<ActionResult> {
  void _previousState;
  void _formData;

  const accountId = await getActiveAccountId();
  if (!accountId) {
    return { error: "No active account." };
  }
  if (!itemId || !objectPath.startsWith(`${accountId}/${itemId}/`)) {
    return { error: "That photo removal is not valid." };
  }

  const supabase = await createClient();
  const rpcParams = {
    p_account_id: accountId,
    p_item_id: itemId,
    p_object_path: objectPath,
  };
  const { error: updateError } = await supabase.rpc("detach_item_photo", rpcParams);
  if (updateError) {
    return { error: userSafeServerError("sell:detach-item-photo", updateError) };
  }

  const { error: storageError } = await supabase.storage.from("item-photos").remove([objectPath]);
  if (storageError) {
    const { error: rollbackError } = await supabase.rpc("attach_item_photo", rpcParams);
    if (rollbackError) {
      userSafeServerError("sell:restore-item-photo-after-storage-error", rollbackError);
    }
    return {
      error: userSafeServerError(
        "sell:remove-item-photo-object",
        storageError,
        "We couldn't remove that photo. Refresh and try again.",
      ),
    };
  }

  revalidatePath("/sell");
  return null;
}

export async function addValuation(_prev: FormState, formData: FormData): Promise<FormState> {
  const itemId = String(formData.get("itemId") ?? "").trim();
  const value = String(formData.get("value") ?? "").trim();
  const estimatedValueCents = parseDollarsToCents(value);

  if (!itemId || estimatedValueCents === null) {
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
  const listPriceCents = listPrice ? parseDollarsToCents(listPrice, { allowZero: true }) : null;

  if (!itemId || !marketplace) {
    return { error: "Marketplace is required." };
  }
  if (listPrice && listPriceCents === null) {
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

  const salePriceCents = parseDollarsToCents(salePrice);
  const feesCents = fees ? parseDollarsToCents(fees, { allowZero: true }) : 0;

  if (!itemId || salePriceCents === null || feesCents === null || feesCents > salePriceCents) {
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
