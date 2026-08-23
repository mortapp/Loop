import { redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";
import { CompleteProfileForm } from "./complete-profile-form";

/**
 * One-time onboarding step reached when either required profile identity
 * field is missing (see /auth/callback and redirectAfterAuth).
 */
export default async function CompleteProfilePage({
  searchParams,
}: {
  searchParams: Promise<{ next?: string }>;
}) {
  const { next } = await searchParams;
  const nextPath = next && next.startsWith("/") ? next : "/today";

  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) {
    redirect("/sign-in");
  }

  const { data: profile } = await supabase
    .from("profiles")
    .select("display_name, username")
    .eq("id", user.id)
    .maybeSingle<{ display_name: string | null; username: string | null }>();

  if (profile?.display_name?.trim() && profile.username?.trim()) {
    redirect(nextPath);
  }

  const metaName =
    (user.user_metadata?.full_name as string | undefined) ??
    (user.user_metadata?.name as string | undefined);
  const suggestedName = metaName || titleCaseFromEmail(user.email?.split("@")[0] ?? "");
  const suggestedUsername = usernameFromEmail(user.email?.split("@")[0] ?? "");

  // Google (or any OAuth-only) sign-up has no password identity yet. LOOP
  // requires one during initial completion so the same account has a backup
  // email/password sign-in path. Existing password accounts skip the fields.
  const hasPasswordIdentity =
    user.identities?.some((identity) => identity.provider === "email") ?? false;

  return (
    <CompleteProfileForm
      suggestedName={suggestedName}
      suggestedUsername={suggestedUsername}
      next={nextPath}
      email={user.email ?? ""}
      requirePasswordSetup={!hasPasswordIdentity}
    />
  );
}

function titleCaseFromEmail(localPart: string): string {
  return localPart
    .replace(/[._-]+/g, " ")
    .trim()
    .split(" ")
    .filter(Boolean)
    .map((word) => word[0]!.toUpperCase() + word.slice(1))
    .join(" ");
}

/** A best-effort, schema-valid ([a-z0-9_]{3,20}) starting guess -- the
 * user can still change it, and availability is checked live. Empty if
 * the email's local part can't produce a valid guess (too short after
 * stripping disallowed characters); the field just starts blank then. */
function usernameFromEmail(localPart: string): string {
  const cleaned = localPart
    .toLowerCase()
    .replace(/[^a-z0-9_]/g, "")
    .slice(0, 20);
  return cleaned.length >= 3 ? cleaned : "";
}
