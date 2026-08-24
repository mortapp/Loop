"use server";

import { revalidatePath } from "next/cache";
import { createClient } from "@/lib/supabase/server";
import { getActiveAccountId } from "@/lib/active-account";
import { MAX_MONEY_CENTS, parseDollarsToCents } from "@/lib/money-input";
import { userSafeServerError } from "@/lib/user-safe-error";
import type { ActionResult } from "@/lib/action-result";

export type CreateQuoteState = { error: string } | null;

const MAX_QUOTE_LINES = 100;
const MAX_QUANTITY = 1_000_000;

const ALLOWED_QUOTE_STATUSES = new Set([
  "draft",
  "sent",
  "viewed",
  "accepted",
  "declined",
  "expired",
] as const);

function generateQuoteNumber(): string {
  const year = new Date().getFullYear();
  const suffix = Math.random().toString(36).slice(2, 7).toUpperCase();
  return `Q-${year}-${suffix}`;
}

export async function createQuote(
  _prev: CreateQuoteState,
  formData: FormData,
): Promise<CreateQuoteState> {
  const contactId = String(formData.get("contactId") ?? "").trim() || null;
  const opportunityId = String(formData.get("opportunityId") ?? "").trim() || null;

  if (!contactId) {
    return { error: "Pick a contact first." };
  }

  const descriptions = formData.getAll("lineDescription").map(String);
  const quantities = formData.getAll("lineQuantity").map(String);
  const unitPrices = formData.getAll("lineUnitPrice").map(String);

  if (descriptions.length > MAX_QUOTE_LINES) {
    return { error: `A quote can contain at most ${MAX_QUOTE_LINES} lines.` };
  }

  const lineItems: Array<{
    description: string;
    quantity: number;
    unitPriceCents: number;
  }> = [];

  for (let index = 0; index < descriptions.length; index += 1) {
    const description = descriptions[index].trim();
    const quantity = Number(quantities[index] ?? "");
    const unitPriceCents = parseDollarsToCents(unitPrices[index] ?? "", {
      allowZero: true,
    });

    if (!description) {
      return { error: `Line ${index + 1} needs a description.` };
    }
    if (description.length > 500) {
      return { error: `Line ${index + 1} must be 500 characters or fewer.` };
    }
    if (!Number.isSafeInteger(quantity) || quantity <= 0 || quantity > MAX_QUANTITY) {
      return { error: `Line ${index + 1} needs a whole-number quantity greater than zero.` };
    }
    if (unitPriceCents === null || unitPriceCents > MAX_MONEY_CENTS) {
      return { error: `Line ${index + 1} needs a valid non-negative unit price.` };
    }

    lineItems.push({ description, quantity, unitPriceCents });
  }

  if (lineItems.length === 0) {
    return { error: "Add at least one line item." };
  }

  let subtotalCents = 0;
  for (const line of lineItems) {
    const lineTotal = line.quantity * line.unitPriceCents;
    if (!Number.isSafeInteger(lineTotal) || !Number.isSafeInteger(subtotalCents + lineTotal)) {
      return { error: "The quote total is too large. Reduce a quantity or unit price." };
    }
    subtotalCents += lineTotal;
  }

  // No tax logic yet — total tracks subtotal until PROTECT/tax rules exist.
  const accountId = await getActiveAccountId();
  if (!accountId) {
    return { error: "No active account." };
  }

  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  // Header + line items are inserted atomically by this RPC (one plpgsql
  // transaction) — see supabase/migrations/20260821235124_quote_rpc.sql.
  const { error } = await supabase.rpc("create_quote_with_line_items", {
    p_account_id: accountId,
    p_contact_id: contactId,
    p_opportunity_id: opportunityId,
    p_quote_number: generateQuoteNumber(),
    p_subtotal_cents: subtotalCents,
    p_tax_cents: 0,
    p_total_cents: subtotalCents,
    p_created_by: user?.id ?? null,
    p_line_items: lineItems.map((line) => ({
      description: line.description,
      quantity: line.quantity,
      unit_price_cents: line.unitPriceCents,
    })),
  });

  if (error) {
    return { error: "Could not create the quote. Check the details and try again." };
  }

  revalidatePath("/business/quotes");
  return null;
}

export async function setQuoteStatus(
  id: string,
  status: "draft" | "sent" | "viewed" | "accepted" | "declined" | "expired",
  _previousState: ActionResult,
  _formData: FormData,
): Promise<ActionResult> {
  void _previousState;
  void _formData;

  if (!id || !ALLOWED_QUOTE_STATUSES.has(status)) {
    return { error: "That quote status is not valid." };
  }

  const accountId = await getActiveAccountId();
  if (!accountId) {
    return { error: "No active account." };
  }

  const supabase = await createClient();
  const { error } = await supabase
    .from("quotes")
    .update({ status })
    .eq("id", id)
    .eq("account_id", accountId)
    .select("id")
    .single();

  if (error) {
    return {
      error: userSafeServerError(
        "quotes:set-status",
        error,
        "We couldn't update that quote. Refresh and try again.",
      ),
    };
  }

  revalidatePath("/business/quotes");
  return null;
}
