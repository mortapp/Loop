import Link from "next/link";
import { redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";
import { getActiveAccountSummary } from "@/lib/active-account";
import { NavLinks } from "@/lib/nav-links";
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
    <div className="flex min-h-full flex-1 flex-col bg-[var(--color-bg)]">
      <header className="border-b border-[var(--color-border-subtle)] bg-[var(--color-bg-secondary)]">
        <div className="mx-auto flex max-w-5xl items-center justify-between px-4 py-3">
          <div className="flex items-center gap-3">
            <span className="text-lg font-semibold tracking-tight text-[var(--color-text-primary)]">
              LOOP
            </span>
            {activeAccount ? (
              <Link
                href="/business"
                className="rounded-full bg-[var(--color-surface)] px-2.5 py-1 text-xs font-medium text-[var(--color-text-secondary)] transition-colors hover:bg-[var(--color-surface-hover)]"
                title="Switch account"
              >
                {activeAccount.label}
              </Link>
            ) : null}
          </div>
          <form action={signOut}>
            <button
              type="submit"
              className="text-sm text-[var(--color-text-tertiary)] transition-colors hover:text-[var(--color-text-primary)]"
            >
              Sign out
            </button>
          </form>
        </div>
        <NavLinks />
      </header>
      <main className="mx-auto w-full max-w-5xl flex-1 px-4 py-8">{children}</main>
    </div>
  );
}
