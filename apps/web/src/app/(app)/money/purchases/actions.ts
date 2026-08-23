"use server";

import { revalidatePath } from "next/cache";
import { createClient } from "@/lib/supabase/server";
import { getActiveAccountId } from "@/lib/active-account";
import { userSafeServerError } from "@/lib/user-safe-error";
import type { ActionResult } from "@/lib/action-result";

export type FormState = { error: string } | null;

const ALLOWED_DIRECT_RETURN_STATUSES = new Set([
  "initiated",
  "shipped",
  "received",
  "denied",
] as const);

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
  const { error } = await supabase.rpc("create_purchase_with_money_event", {
    p_account_id: accountId,
    p_item_id: itemId,
    p_vendor_name: vendorName,
    p_purchase_date: purchaseDate,
    p_price_cents: priceCents,
    p_return_window_expires_at: returnWindowExpiresAt,
    p_warranty_expires_at: warrantyExpiresAt,
  });

  if (error) {
    return { error: "Could not save this purchase. Please try again." };
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
    return { error: userSafeServerError("returns:create", error) };
  }

  revalidatePath("/money/purchases");
  return null;
}

export async function setReturnStatus(
  id: string,
  status: "initiated" | "shipped" | "received" | "denied",
  _previousState: ActionResult,
  _formData: FormData,
): Promise<ActionResult> {
  void _previousState;
  void _formData;

  if (!id || !ALLOWED_DIRECT_RETURN_STATUSES.has(status)) {
    return { error: "That return status is not valid." };
  }

  const accountId = await getActiveAccountId();
  if (!accountId) {
    return { error: "No active account." };
  }

  const supabase = await createClient();
  const patch: Record<string, unknown> = { status };
  if (status === "denied") {
    patch.resolved_at = new Date().toISOString();
  }
  const { error } = await supabase
    .from("returns")
    .update(patch)
    .eq("id", id)
    .eq("account_id", accountId)
    .select("id")
    .single();

  if (error) {
    return {
      error: userSafeServerError(
        "returns:set-status",
        error,
        "We couldn't update that return. Refresh and try again.",
      ),
    };
  }

  revalidatePath("/money/purchases");
  return null;
}

export async function refundReturn(_prev: FormState, formData: FormData): Promise<FormState> {
  const returnId = String(formData.get("returnId") ?? "").trim();
  const itemId = String(formData.get("itemId") ?? "").trim();
  const amount = String(formData.get("amount") ?? "").trim();
  const refundAmountCents = Math.round(Number(amount) * 100);

  if (
    !returnId ||
    !itemId ||
    !amount ||
    !Number.isFinite(refundAmountCents) ||
    refundAmountCents <= 0
  ) {
    return { error: "Enter a valid refund amount." };
  }

  const accountId = await getActiveAccountId();
  if (!accountId) {
    return { error: "No active account." };
  }

  const supabase = await createClient();
  const { error } = await supabase.rpc("refund_return_with_money_event", {
    p_account_id: accountId,
    p_return_id: returnId,
    p_item_id: itemId,
    p_refund_amount_cents: refundAmountCents,
  });

  if (error) {
    return { error: "Could not record this refund. Please try again." };
  }

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
    return { error: userSafeServerError("warranties:create", error) };
  }

  revalidatePath("/money/purchases");
  return null;
}

export async function setWarrantyClaimStatus(
  id: string,
  claimStatus: "filed",
  _previousState: ActionResult,
  _formData: FormData,
): Promise<ActionResult> {
  void _previousState;
  void _formData;

  if (!id || claimStatus !== "filed") {
    return { error: "That warranty change is not valid." };
  }

  const accountId = await getActiveAccountId();
  if (!accountId) {
    return { error: "No active account." };
  }

  const supabase = await createClient();
  const { error } = await supabase
    .from("warranties")
    .update({ claim_status: claimStatus })
    .eq("id", id)
    .eq("account_id", accountId)
    .select("id")
    .single();

  if (error) {
    return {
      error: userSafeServerError(
        "warranties:file-claim",
        error,
        "We couldn't file that warranty claim. Refresh and try again.",
      ),
    };
  }

  revalidatePath("/money/purchases");
  return null;
}
