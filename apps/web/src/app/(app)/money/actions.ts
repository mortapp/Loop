"use server";

import { revalidatePath } from "next/cache";
import { createClient } from "@/lib/supabase/server";
import { getActiveAccountId } from "@/lib/active-account";

export type FormState = { error: string } | null;

const KINDS = ["earn", "spend", "refund", "fee", "recovered"] as const;

export async function logMoneyEvent(_prev: FormState, formData: FormData): Promise<FormState> {
  const kind = String(formData.get("kind") ?? "");
  const amount = String(formData.get("amount") ?? "").trim();
  const description = String(formData.get("description") ?? "").trim() || null;

  if (!KINDS.includes(kind as (typeof KINDS)[number])) {
    return { error: "Pick a valid kind." };
  }

  const amountCents = Math.round(Number(amount) * 100);
  if (!amount || !Number.isFinite(amountCents) || amountCents <= 0) {
    return { error: "Enter a valid amount." };
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
    description,
    created_by: user?.id ?? null,
  });

  if (error) {
    return { error: error.message };
  }

  revalidatePath("/money");
  return null;
}
