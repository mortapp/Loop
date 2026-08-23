import { NextResponse } from "next/server";
import { createClient } from "@/lib/supabase/server";

/**
 * PKCE callback for Supabase Auth (email confirmation links, web's own
 * Google OAuth). Exchanges the `code` query param for a session, then
 * either redirects into the app or, for a brand-new account (no
 * display_name set yet), through /auth/complete-profile first.
 *
 * This route is web-only. Mobile's OAuth/email-confirmation redirect
 * points at the app's own custom URL scheme
 * (com.loop.app.loop_mobile://login-callback), never here — the PKCE
 * code_verifier for a mobile-initiated flow lives in the app's local
 * storage, which this server has no access to, so it could never
 * complete that exchange anyway. If that scheme isn't in the Supabase
 * project's Auth > URL Configuration > Redirect URLs allow-list,
 * Supabase falls back to the Site URL and a mobile user ends up here
 * instead, where the exchange fails as expected -- see
 * docs/KNOWN_ISSUES.md for the real bug this was found from and the
 * exact owner action that fixes it at the source.
 *
 * The redirect target is derived from the incoming request's own origin
 * (localhost in dev, the actual preview/production URL on Vercel), never
 * hardcoded — see docs/VERCEL_DEPLOYMENT.md.
 */
export async function GET(request: Request) {
  const { searchParams, origin } = new URL(request.url);
  const code = searchParams.get("code");
  const next = searchParams.get("next") ?? "/today";

  if (code) {
    const supabase = await createClient();
    const { error } = await supabase.auth.exchangeCodeForSession(code);
    if (!error) {
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
          return NextResponse.redirect(
            `${origin}/auth/complete-profile?next=${encodeURIComponent(next)}`,
          );
        }
      }

      return NextResponse.redirect(`${origin}${next}`);
    }
  }

  return NextResponse.redirect(`${origin}/sign-in?error=auth_callback_failed`);
}
