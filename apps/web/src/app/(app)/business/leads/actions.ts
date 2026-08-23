"use server";

import { revalidatePath } from "next/cache";
import { createClient } from "@/lib/supabase/server";
import { getActiveAccountId } from "@/lib/active-account";
import { userSafeServerError } from "@/lib/user-safe-error";
import type { ActionResult } from "@/lib/action-result";

export type CreateLeadState = { error: string } | null;

const ALLOWED_LEAD_STATUSES = new Set([
  "new",
  "contacted",
  "qualified",
  "disqualified",
  "converted",
] as const);

export async function createLead(
  _prev: CreateLeadState,
  formData: FormData,
): Promise<CreateLeadState> {
  const contactId = String(formData.get("contactId") ?? "").trim() || null;
  const source = String(formData.get("source") ?? "").trim() || null;
  const notes = String(formData.get("notes") ?? "").trim() || null;

  if (!contactId) {
    return { error: "Pick a contact first (add one under Contacts if the list is empty)." };
  }

  const accountId = await getActiveAccountId();
  if (!accountId) {
    return { error: "No active account." };
  }

  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  const { error } = await supabase.from("leads").insert({
    account_id: accountId,
    contact_id: contactId,
    source,
    notes,
    created_by: user?.id ?? null,
  });

  if (error) {
    return { error: userSafeServerError("leads:create", error) };
  }

  revalidatePath("/business/leads");
  return null;
}

export async function setLeadStatus(
  id: string,
  status: "new" | "contacted" | "qualified" | "disqualified" | "converted",
  _previousState: ActionResult,
  _formData: FormData,
): Promise<ActionResult> {
  void _previousState;
  void _formData;

  if (!id || !ALLOWED_LEAD_STATUSES.has(status)) {
    return { error: "That lead status is not valid." };
  }

  const accountId = await getActiveAccountId();
  if (!accountId) {
    return { error: "No active account." };
  }

  const supabase = await createClient();
  const { error } = await supabase
    .from("leads")
    .update({ status })
    .eq("id", id)
    .eq("account_id", accountId)
    .select("id")
    .single();

  if (error) {
    return {
      error: userSafeServerError(
        "leads:set-status",
        error,
        "We couldn't update that lead. Refresh and try again.",
      ),
    };
  }

  revalidatePath("/business/leads");
  return null;
}
