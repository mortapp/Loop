"use server";

import { revalidatePath } from "next/cache";
import { createClient } from "@/lib/supabase/server";
import { getActiveAccountId } from "@/lib/active-account";
import { userSafeServerError } from "@/lib/user-safe-error";

export type CreateLeadState = { error: string } | null;

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
) {
  const supabase = await createClient();
  await supabase.from("leads").update({ status }).eq("id", id);
  revalidatePath("/business/leads");
}
