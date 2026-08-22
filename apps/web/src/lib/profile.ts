import { createClient } from "@/lib/supabase/server";

export type Profile = {
  id: string;
  email: string;
  displayName: string | null;
  avatarUrl: string | null;
};

/** The signed-in user's own `profiles` row. Null only if genuinely
 * unauthenticated — every authenticated user has one (created by the
 * `handle_new_user` trigger on `auth.users` insert). */
export async function getCurrentProfile(): Promise<Profile | null> {
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) return null;

  const { data } = await supabase
    .from("profiles")
    .select("id, email, display_name, avatar_url")
    .eq("id", user.id)
    .single();
  if (!data) return null;

  return {
    id: data.id,
    email: data.email,
    displayName: data.display_name,
    avatarUrl: data.avatar_url,
  };
}

/** Deterministic initials from a display name or email — never a random
 * color/glyph per launch. "Ada Lovelace" -> "AL", "ada@x.com" -> "A". */
export function initialsFor(displayName: string | null, email: string): string {
  const source = displayName?.trim() || email;
  const parts = source.split(/\s+/).filter(Boolean);
  if (parts.length >= 2) {
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }
  return source.slice(0, 2).toUpperCase();
}
