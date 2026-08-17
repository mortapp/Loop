"use server";

import { revalidatePath } from "next/cache";
import { createClient } from "@/lib/supabase/server";
import { getActiveAccountId } from "@/lib/active-account";

export type CreateActionState = { error: string } | null;

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
    return { error: error.message };
  }

  revalidatePath("/today");
  return null;
}

export async function setActionStatus(id: string, status: "done" | "dismissed" | "open") {
  const supabase = await createClient();
  await supabase
    .from("actions")
    .update({
      status,
      completed_at: status === "done" ? new Date().toISOString() : null,
    })
    .eq("id", id);

  revalidatePath("/today");
}
