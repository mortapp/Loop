import { NextResponse } from "next/server";
import { createClient } from "@/lib/supabase/server";

/**
 * PKCE callback for Supabase Auth (email confirmation links, OAuth
 * providers once configured). Exchanges the `code` query param for a
 * session, then redirects into the app.
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
      return NextResponse.redirect(`${origin}${next}`);
    }
  }

  return NextResponse.redirect(`${origin}/sign-in?error=auth_callback_failed`);
}
