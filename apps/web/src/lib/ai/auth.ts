import { createClient as createSupabaseJsClient, type SupabaseClient } from "@supabase/supabase-js";
import { createClient as createServerClient } from "@/lib/supabase/server";
import { getActiveAccountId } from "@/lib/active-account";

export type AiAuthResult =
  | { supabase: SupabaseClient; userId: string; accountId: string }
  | { error: string; status: number };

/**
 * The one auth boundary both AI routes (chat, confirm) go through —
 * deliberately the SAME product contract for web and mobile, not a
 * parallel architecture. Web's browser fetch calls carry no
 * `Authorization` header and rely on the existing cookie session
 * (`@/lib/supabase/server`'s SSR client), exactly as before this
 * function existed. Mobile has no cookie jar, so it sends
 * `Authorization: Bearer <supabase access token>` (the same JWT
 * `supabase_flutter` already attaches to every other request it makes)
 * plus an explicit `accountId` in the request body (mobile tracks its
 * active account in memory, not a cookie) — that combination is
 * verified here and never trusted blindly: `accountId` is only ever
 * used as a query filter, and every downstream read/write still goes
 * through the same RLS policies (`has_account_access`) that protect
 * every other table, so a client-supplied account id a user doesn't
 * actually belong to is rejected by the database, not by this check.
 */
export async function resolveAiRequest(
  request: Request,
  bodyAccountId?: string,
): Promise<AiAuthResult> {
  const authHeader = request.headers.get("authorization");

  if (authHeader?.startsWith("Bearer ")) {
    const supabase = createSupabaseJsClient(
      process.env.NEXT_PUBLIC_SUPABASE_URL!,
      process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
      { global: { headers: { Authorization: authHeader } } },
    );
    const {
      data: { user },
    } = await supabase.auth.getUser();
    if (!user) return { error: "Not signed in.", status: 401 };
    if (!bodyAccountId) return { error: "No active account.", status: 400 };
    return { supabase, userId: user.id, accountId: bodyAccountId };
  }

  const supabase = await createServerClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) return { error: "Not signed in.", status: 401 };

  const accountId = bodyAccountId ?? (await getActiveAccountId());
  if (!accountId) return { error: "No active account.", status: 400 };

  return { supabase, userId: user.id, accountId };
}
