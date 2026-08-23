"use server";

import { revalidatePath } from "next/cache";
import { createClient } from "@/lib/supabase/server";
import { getActiveAccountId } from "@/lib/active-account";
import { userSafeServerError } from "@/lib/user-safe-error";
import type { ActionResult } from "@/lib/action-result";

export type CreateActionState = { error: string } | null;

const ALLOWED_ACTION_STATUSES = new Set(["done", "dismissed", "open"] as const);

export async function createAction(
  _prev: CreateActionState,
  formData: FormData,
): Promise<CreateActionState> {
  const title = String(formData.get("title") ?? "").trim();
  if (!title) {
    return { error: "Title is required." };
  }

  const accountId = await getActiveAccountId();
  if (!accountId) {
    return { error: "No active account." };
  }

  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  const { error } = await supabase.from("actions").insert({
    account_id: accountId,
    type: "manual",
    title,
    created_by: user?.id ?? null,
  });

  if (error) {
    return { error: userSafeServerError("today:create-action", error) };
  }

  revalidatePath("/today");
  return null;
}

export async function setActionStatus(
  id: string,
  status: "done" | "dismissed" | "open",
  _previousState: ActionResult,
  _formData: FormData,
): Promise<ActionResult> {
  void _previousState;
  void _formData;

  if (!id || !ALLOWED_ACTION_STATUSES.has(status)) {
    return { error: "That action change is not valid." };
  }

  const accountId = await getActiveAccountId();
  if (!accountId) {
    return { error: "No active account." };
  }

  const supabase = await createClient();
  const { error } = await supabase
    .from("actions")
    .update({
      status,
      completed_at: status === "done" ? new Date().toISOString() : null,
    })
    .eq("id", id)
    .eq("account_id", accountId)
    .select("id")
    .single();

  if (error) {
    return {
      error: userSafeServerError(
        "today:set-action-status",
        error,
        "We couldn't update that action. Refresh and try again.",
      ),
    };
  }

  revalidatePath("/today");
  return null;
}
