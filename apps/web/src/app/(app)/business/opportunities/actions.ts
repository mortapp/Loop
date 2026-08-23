"use server";

import { revalidatePath } from "next/cache";
import { createClient } from "@/lib/supabase/server";
import { getActiveAccountId } from "@/lib/active-account";
import { userSafeServerError } from "@/lib/user-safe-error";
import type { ActionResult } from "@/lib/action-result";

export type CreateOpportunityState = { error: string } | null;

const ALLOWED_OPPORTUNITY_STAGES = new Set([
  "new",
  "qualifying",
  "quoted",
  "negotiating",
  "won",
  "lost",
] as const);

export async function createOpportunity(
  _prev: CreateOpportunityState,
  formData: FormData,
): Promise<CreateOpportunityState> {
  const contactId = String(formData.get("contactId") ?? "").trim() || null;
  const title = String(formData.get("title") ?? "").trim();
  const estimatedValue = String(formData.get("estimatedValue") ?? "").trim();

  if (!contactId) {
    return { error: "Pick a contact first." };
  }
  if (!title) {
    return { error: "Title is required." };
  }

  const estimatedValueCents = estimatedValue ? Math.round(Number(estimatedValue) * 100) : null;
  if (estimatedValue && !Number.isFinite(estimatedValueCents)) {
    return { error: "Estimated value must be a number." };
  }

  const accountId = await getActiveAccountId();
  if (!accountId) {
    return { error: "No active account." };
  }

  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  const { error } = await supabase.from("opportunities").insert({
    account_id: accountId,
    contact_id: contactId,
    title,
    estimated_value_cents: estimatedValueCents,
    created_by: user?.id ?? null,
  });

  if (error) {
    return { error: userSafeServerError("opportunities:create", error) };
  }

  revalidatePath("/business/opportunities");
  return null;
}

export async function setOpportunityStage(
  id: string,
  stage: "new" | "qualifying" | "quoted" | "negotiating" | "won" | "lost",
  _previousState: ActionResult,
  _formData: FormData,
): Promise<ActionResult> {
  void _previousState;
  void _formData;

  if (!id || !ALLOWED_OPPORTUNITY_STAGES.has(stage)) {
    return { error: "That opportunity stage is not valid." };
  }

  const accountId = await getActiveAccountId();
  if (!accountId) {
    return { error: "No active account." };
  }

  const supabase = await createClient();
  const { error } = await supabase
    .from("opportunities")
    .update({ stage })
    .eq("id", id)
    .eq("account_id", accountId)
    .select("id")
    .single();

  if (error) {
    return {
      error: userSafeServerError(
        "opportunities:set-stage",
        error,
        "We couldn't update that opportunity. Refresh and try again.",
      ),
    };
  }

  revalidatePath("/business/opportunities");
  return null;
}
