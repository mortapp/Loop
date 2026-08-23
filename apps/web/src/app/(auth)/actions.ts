"use server";

import { redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";
import { redirectAfterAuth } from "@/lib/auth/post-auth-redirect";
import { userSafeAuthError } from "@/lib/user-safe-error";

export type AuthActionState = { error: string } | null;

export async function signIn(_prev: AuthActionState, formData: FormData): Promise<AuthActionState> {
  const email = String(formData.get("email") ?? "");
  const password = String(formData.get("password") ?? "");

  const supabase = await createClient();
  const { error } = await supabase.auth.signInWithPassword({ email, password });
  if (error) {
    return { error: userSafeAuthError("sign-in", error) };
  }

  return redirectAfterAuth(supabase, "/today");
}

export async function signUp(_prev: AuthActionState, formData: FormData): Promise<AuthActionState> {
  const email = String(formData.get("email") ?? "");
  const password = String(formData.get("password") ?? "");

  const supabase = await createClient();
  const { data, error } = await supabase.auth.signUp({
    email,
    password,
    options: {
      emailRedirectTo: `${process.env.NEXT_PUBLIC_SITE_URL ?? ""}/auth/callback`,
    },
  });
  if (error) {
    return { error: userSafeAuthError("sign-up", error) };
  }

  // If the project requires email confirmation, signUp succeeds but
  // returns no session -- there's nothing to redirect into yet.
  if (!data.session) {
    redirect("/sign-in?notice=check_email");
  }

  return redirectAfterAuth(supabase, "/today");
}

export async function signOut() {
  const supabase = await createClient();
  await supabase.auth.signOut();
  redirect("/sign-in");
}
