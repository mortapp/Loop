import { redirect } from "next/navigation";
import type { SupabaseClient } from "@supabase/supabase-js";

/**
 * Sends a signed-in user to `next` -- or, first, to the one-time
 * profile-completion step if they've never set a display name.
 * `profiles.display_name` starts null for every account regardless of
 * how they signed up (Google OAuth or email/password -- see
 * handle_new_user() in supabase/migrations/20260817000002_identity.sql),
 * so "display_name is null" is exactly "this person has never finished
 * onboarding," not specific to any one auth method.
 */
export async function redirectAfterAuth(supabase: SupabaseClient, next: string): Promise<never> {
  const {
    data: { user },
  } = await supabase.auth.getUser();

  if (user) {
    const { data: profile } = await supabase
      .from("profiles")
      .select("display_name")
      .eq("id", user.id)
      .maybeSingle<{ display_name: string | null }>();

    if (!profile?.display_name) {
      redirect(`/auth/complete-profile?next=${encodeURIComponent(next)}`);
    }
  }

  redirect(next);
}
