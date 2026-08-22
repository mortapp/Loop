import { redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";
import { getActiveAccountSummary } from "@/lib/active-account";
import { AppShell } from "@/components/app-shell";
import { signOut } from "../(auth)/actions";

/**
 * The authenticated app shell. src/proxy.ts already redirects unauthenticated
 * requests to /sign-in before they reach here; this check is a defense in
 * depth, not the primary gate (Server Components should never trust that
 * proxy always ran, e.g. during local static analysis or future route
 * changes that miss the matcher).
 */
export default async function AppLayout({ children }: { children: React.ReactNode }) {
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  if (!user) {
    redirect("/sign-in");
  }

  const activeAccount = await getActiveAccountSummary();

  return (
    <AppShell activeAccountLabel={activeAccount?.label ?? null} signOutAction={signOut}>
      {children}
    </AppShell>
  );
}
