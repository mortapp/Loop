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

  return <CompleteProfileForm suggestedName={suggestedName} next={nextPath} />;
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
