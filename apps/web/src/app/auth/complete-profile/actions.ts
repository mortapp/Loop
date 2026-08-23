"use server";

import { redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";

export type CompleteProfileState = { error: string } | null;

/**
 * One-time onboarding step: set the display name every account starts
 * with as null (see redirectAfterAuth). Bound with the target `next`
 * path from the calling page via `.bind(null, next)`.
 */
export async function completeProfile(
  next: string,
  _prev: CompleteProfileState,
  formData: FormData,
): Promise<CompleteProfileState> {
  const displayName = String(formData.get("displayName") ?? "").trim();
  if (!displayName) {
    return { error: "Enter a name." };
  }

  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) {
    redirect("/sign-in");
  }

  const { error } = await supabase.from("profiles").update({ display_name: displayName }).eq("id", user.id);
  if (error) {
    return { error: error.message };
  }

  redirect(next);
}
