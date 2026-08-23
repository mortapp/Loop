import { redirect } from "next/navigation";
import type { SupabaseClient } from "@supabase/supabase-js";

/**
 * Sends a signed-in user to `next` -- or, first, to the one-time
 * profile-completion step if either required identity field is missing.
 * `profiles.display_name` and `profiles.username` start null regardless of
 * how they signed up (Google OAuth or email/password -- see
 * handle_new_user() in supabase/migrations/20260821234807_identity.sql),
 * so the database row is the cross-platform onboarding authority, not any
 * client-local flag or auth provider.
 */
export async function redirectAfterAuth(supabase: SupabaseClient, next: string): Promise<never> {
  const {
    data: { user },
  } = await supabase.auth.getUser();

  if (user) {
    const { data: profile } = await supabase
      .from("profiles")
      .select("display_name, username")
      .eq("id", user.id)
      .maybeSingle<{ display_name: string | null; username: string | null }>();

    if (!profile?.display_name?.trim() || !profile.username?.trim()) {
      redirect(`/auth/complete-profile?next=${encodeURIComponent(next)}`);
    }
  }

  redirect(next);
}
