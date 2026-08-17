import { cookies } from "next/headers";
import { createClient } from "./supabase/server";

/**
 * Which account (personal or a business) the signed-in user is currently
 * acting as. Persisted as a cookie so every server component in a request
 * agrees without re-deriving it. The cookie is advisory only — every query
 * scoped by account_id is still enforced by RLS (has_account_access), so a
 * stale/tampered cookie value can at worst select an account the user
 * already has access to, or return nothing.
 */
const ACTIVE_ACCOUNT_COOKIE = "loop_active_account";

export async function getActiveAccountId(): Promise<string | null> {
  const cookieStore = await cookies();
  const fromCookie = cookieStore.get(ACTIVE_ACCOUNT_COOKIE)?.value;
  if (fromCookie) {
    return fromCookie;
  }

  // No selection yet — default to the user's personal account.
  const supabase = await createClient();
  const { data } = await supabase
    .from("accounts")
    .select("id")
    .eq("type", "personal")
    .maybeSingle();

  return data?.id ?? null;
}

export async function setActiveAccountId(accountId: string): Promise<void> {
  const cookieStore = await cookies();
  cookieStore.set(ACTIVE_ACCOUNT_COOKIE, accountId, {
    path: "/",
    maxAge: 60 * 60 * 24 * 365,
    sameSite: "lax",
  });
}

export type ActiveAccountSummary = {
  id: string;
  label: string;
};

export async function getActiveAccountSummary(): Promise<ActiveAccountSummary | null> {
  const accountId = await getActiveAccountId();
  if (!accountId) {
    return null;
  }

  const supabase = await createClient();
  const { data } = await supabase
    .from("accounts")
    .select("id, type, businesses(name)")
    .eq("id", accountId)
    .maybeSingle<{ id: string; type: "personal" | "business"; businesses: { name: string } | null }>();

  if (!data) {
    return null;
  }

  return {
    id: data.id,
    label: data.type === "personal" ? "Personal" : (data.businesses?.name ?? "Business"),
  };
}
