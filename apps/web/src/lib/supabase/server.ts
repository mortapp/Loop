import { cookies } from "next/headers";
import { createServerClient } from "@supabase/ssr";

/**
 * Supabase client for use in Server Components, Server Actions, and Route
 * Handlers. Must be created fresh per request (it closes over the request's
 * cookie jar) — never module-level singleton this.
 *
 * Server Components can't write cookies, so `setAll` there is a no-op
 * wrapped in try/catch; session refresh cookies are actually persisted by
 * `src/proxy.ts`, which runs on every request.
 */
export async function createClient() {
  const cookieStore = await cookies();

  return createServerClient(process.env.NEXT_PUBLIC_SUPABASE_URL!, process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!, {
    cookies: {
      getAll() {
        return cookieStore.getAll();
      },
      setAll(cookiesToSet) {
        try {
          for (const { name, value, options } of cookiesToSet) {
            cookieStore.set(name, value, options);
          }
        } catch {
          // Called from a Server Component — ignore. src/proxy.ts refreshes
          // the session on every request, so this is never load-bearing.
        }
      },
    },
  });
}
