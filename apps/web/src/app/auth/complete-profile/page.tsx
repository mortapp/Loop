import { redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";
import { CompleteProfileForm } from "./complete-profile-form";

/**
 * One-time onboarding step reached only when profiles.display_name is
 * still null (see /auth/callback and (auth)/actions.ts's
 * redirectAfterAuth) -- true for every brand-new account regardless of
 * whether they signed up with Google or email/password. An existing
 * account with a name already set never sees this page.
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
    .select("display_name")
    .eq("id", user.id)
    .maybeSingle<{ display_name: string | null }>();

  if (profile?.display_name) {
    redirect(nextPath);
  }

  const metaName =
    (user.user_metadata?.full_name as string | undefined) ?? (user.user_metadata?.name as string | undefined);
  const suggestedName = metaName || titleCaseFromEmail(user.email?.split("@")[0] ?? "");
  const suggestedUsername = usernameFromEmail(user.email?.split("@")[0] ?? "");

  // Google (or any OAuth-only) sign-up has no password identity yet --
  // offer to set one so the same account can also sign in with email/
  // password later. An account that already has one (signed up with
  // email/password originally, or already linked one) skips this.
  const hasPasswordIdentity = user.identities?.some((identity) => identity.provider === "email") ?? false;

  return (
    <CompleteProfileForm
      suggestedName={suggestedName}
      suggestedUsername={suggestedUsername}
      next={nextPath}
      email={user.email ?? ""}
      offerPasswordSetup={!hasPasswordIdentity}
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
  const cleaned = localPart.toLowerCase().replace(/[^a-z0-9_]/g, "").slice(0, 20);
  return cleaned.length >= 3 ? cleaned : "";
}
