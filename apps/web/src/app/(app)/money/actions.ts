"use server";

import { revalidatePath } from "next/cache";
import { createClient } from "@/lib/supabase/server";
import { getActiveAccountId } from "@/lib/active-account";
import { isUuid, parseDollarsToCents } from "@/lib/money-input";
import { userSafeServerError } from "@/lib/user-safe-error";

export type FormState = { error: string } | null;

const KINDS = ["earn", "spend", "refund", "fee", "recovered"] as const;

export async function logMoneyEvent(_prev: FormState, formData: FormData): Promise<FormState> {
  const kind = String(formData.get("kind") ?? "");
  const amount = String(formData.get("amount") ?? "").trim();
  const description = String(formData.get("description") ?? "").trim() || null;
  const requestId = String(formData.get("requestId") ?? "").trim();

  if (!KINDS.includes(kind as (typeof KINDS)[number])) {
    return { error: "Pick a valid kind." };
  }

  const amountCents = parseDollarsToCents(amount);
  if (amountCents === null) {
    return { error: "Enter a valid amount." };
  }
  if (!isUuid(requestId)) {
    return { error: "This entry expired. Refresh and try again." };
  }
  if (description && description.length > 500) {
    return { error: "Description must be 500 characters or fewer." };
  }

  const accountId = await getActiveAccountId();
  if (!accountId) {
    return { error: "No active account." };
  }

  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  const { error } = await supabase.from("money_events").insert({
    account_id: accountId,
    kind,
    amount_cents: amountCents,
    source_type: "manual",
    source_id: requestId,
    description,
    created_by: user?.id ?? null,
  });

  if (error) {
    if (error.code === "23505") {
      const { data: existing, error: lookupError } = await supabase
        .from("money_events")
        .select("kind, amount_cents, description")
        .eq("account_id", accountId)
        .eq("source_type", "manual")
        .eq("source_id", requestId)
        .maybeSingle();
      if (
        !lookupError &&
        existing?.kind === kind &&
        Number(existing.amount_cents) === amountCents &&
        (existing.description ?? null) === description
      ) {
        revalidatePath("/money");
        return null;
      }
    }
    return { error: userSafeServerError("money:create-event", error) };
  }

  revalidatePath("/money");
  return null;
}
