"use server";

import { revalidatePath } from "next/cache";
import { createClient } from "@/lib/supabase/server";
import { getActiveAccountId } from "@/lib/active-account";
import { userSafeServerError } from "@/lib/user-safe-error";

export type CreateContactState = { error: string } | null;

export async function createContact(
  _prev: CreateContactState,
  formData: FormData,
): Promise<CreateContactState> {
  const displayName = String(formData.get("displayName") ?? "").trim();
  if (!displayName) {
    return { error: "Name is required." };
  }

  const email = String(formData.get("email") ?? "").trim() || null;
  const phone = String(formData.get("phone") ?? "").trim() || null;
  const company = String(formData.get("company") ?? "").trim() || null;

  const accountId = await getActiveAccountId();
  if (!accountId) {
    return { error: "No active account." };
  }

  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  const { error } = await supabase.from("contacts").insert({
    account_id: accountId,
    display_name: displayName,
    email,
    phone,
    company,
    created_by: user?.id ?? null,
  });

  if (error) {
    return { error: userSafeServerError("contacts:create", error) };
  }

  revalidatePath("/business/contacts");
  return null;
}
