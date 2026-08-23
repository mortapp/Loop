"use server";

import { redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";

export type CompleteProfileState = { error: string } | null;

/**
 * One-time onboarding step: set the display name and username every
 * account starts with as null (see redirectAfterAuth), and -- only for
 * accounts with no password identity yet (Google-only signups) --
 * optionally link a password via Supabase's own updateUser, so the
 * SAME auth user (same id) can also sign in with email/password
 * afterward. Never a second account. Bound with the target `next` path
 * from the calling page via `.bind(null, next)`.
 */
export async function completeProfile(
  next: string,
  _prev: CompleteProfileState,
  formData: FormData,
): Promise<CompleteProfileState> {
  const displayName = String(formData.get("displayName") ?? "").trim();
  const username = String(formData.get("username") ?? "")
    .trim()
    .toLowerCase();
  const password = String(formData.get("password") ?? "");
  const confirmPassword = String(formData.get("confirmPassword") ?? "");

  if (!displayName) {
    return { error: "Enter a name." };
  }
  if (!username) {
    return { error: "Choose a username." };
  }
  if (!/^[a-z0-9_]{3,20}$/.test(username)) {
    return { error: "Usernames are 3-20 characters: lowercase letters, numbers, and underscores only." };
  }

  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) {
    redirect("/sign-in");
  }

  // Only ask for/accept a password when there's genuinely no password
  // identity yet -- an account that already has one shouldn't have its
  // password silently changed by this step.
  const hasPasswordIdentity = user.identities?.some((identity) => identity.provider === "email") ?? false;
  if (!hasPasswordIdentity && (password || confirmPassword)) {
    if (password.length < 8) {
      return { error: "Password must be at least 8 characters." };
    }
    if (password !== confirmPassword) {
      return { error: "Passwords don't match." };
    }
    const { error: passwordError } = await supabase.auth.updateUser({ password });
    if (passwordError) {
      return { error: passwordError.message };
    }
  }

  const { error } = await supabase
    .from("profiles")
    .update({ display_name: displayName, username })
    .eq("id", user.id);

  if (error) {
    if (error.code === "23505") {
      return { error: "That username is already taken." };
    }
    if (error.code === "23514") {
      return { error: "That username isn't allowed. Try a different one." };
    }
    return { error: error.message };
  }

  redirect(next);
}
