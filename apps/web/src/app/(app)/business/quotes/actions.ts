"use server";

import { revalidatePath } from "next/cache";
import { createClient } from "@/lib/supabase/server";
import { getActiveAccountId } from "@/lib/active-account";

export type CreateQuoteState = { error: string } | null;

function generateQuoteNumber(): string {
  const year = new Date().getFullYear();
  const suffix = Math.random().toString(36).slice(2, 7).toUpperCase();
  return `Q-${year}-${suffix}`;
}

export async function createQuote(_prev: CreateQuoteState, formData: FormData): Promise<CreateQuoteState> {
  const contactId = String(formData.get("contactId") ?? "").trim() || null;
  const opportunityId = String(formData.get("opportunityId") ?? "").trim() || null;

  if (!contactId) {
    return { error: "Pick a contact first." };
  }

  const descriptions = formData.getAll("lineDescription").map(String);
  const quantities = formData.getAll("lineQuantity").map(String);
  const unitPrices = formData.getAll("lineUnitPrice").map(String);

  const lineItems = descriptions
    .map((description, i) => ({
      description: description.trim(),
      quantity: Number(quantities[i] ?? "1") || 0,
      unitPriceCents: Math.round(Number(unitPrices[i] ?? "0") * 100) || 0,
    }))
    .filter((line) => line.description.length > 0 && line.quantity > 0);

  if (lineItems.length === 0) {
    return { error: "Add at least one line item with a description and quantity." };
  }

  const subtotalCents = lineItems.reduce(
    (sum, line) => sum + Math.round(line.quantity * line.unitPriceCents),
    0,
  );

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
  // transaction) — see supabase/migrations/20260817000008_quote_rpc.sql.
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
    return { error: error.message };
  }

  revalidatePath("/business/quotes");
  return null;
}

export async function setQuoteStatus(
  id: string,
  status: "draft" | "sent" | "viewed" | "accepted" | "declined" | "expired",
) {
  const supabase = await createClient();
  const patch: Record<string, unknown> = { status };
  if (status === "sent") patch.sent_at = new Date().toISOString();
  if (status === "accepted") patch.accepted_at = new Date().toISOString();

  await supabase.from("quotes").update(patch).eq("id", id);
  revalidatePath("/business/quotes");
}
