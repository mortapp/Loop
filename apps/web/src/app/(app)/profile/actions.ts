"use server";

import { revalidatePath } from "next/cache";
import { createClient } from "@/lib/supabase/server";
import { userSafeServerError } from "@/lib/user-safe-error";

export type FormState = { error: string } | null;

export async function updateProfile(_prev: FormState, formData: FormData): Promise<FormState> {
  const displayName = String(formData.get("displayName") ?? "").trim();
  if (!displayName) {
    return { error: "Name is required." };
  }
  if (displayName.length > 80) {
    return { error: "Name must be 80 characters or fewer." };
  }

  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) {
    return { error: "Not signed in." };
  }

  const { error } = await supabase
    .from("profiles")
    .update({ display_name: displayName })
    .eq("id", user.id);

  if (error) {
    return { error: userSafeServerError("profile:update", error) };
  }

  revalidatePath("/profile");
  revalidatePath("/", "layout");
  return null;
}
