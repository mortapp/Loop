import Link from "next/link";
import { createClient } from "@/lib/supabase/server";
import { getActiveAccountId } from "@/lib/active-account";
import { Card } from "@/components/ui/card";
import { StatusBadge } from "@/components/ui/status-badge";
import { CreateBusinessForm } from "./create-business-form";
import { switchActiveAccount } from "./actions";

type AccountRow = {
  id: string;
  type: "personal" | "business";
  businesses: { id: string; name: string; slug: string } | null;
};

const HUB_LINKS = [
  { href: "/business/contacts", label: "Contacts", description: "Customers, vendors, and anyone else you deal with." },
  { href: "/business/leads", label: "Leads", description: "MAKE / QuoteCloser — track interest before it's worth quoting." },
  { href: "/business/opportunities", label: "Opportunities", description: "Qualified interest, tracked through to won or lost." },
  { href: "/business/quotes", label: "Quotes", description: "Line items, totals, and status — the close." },
] as const;

export default async function BusinessPage() {
  const supabase = await createClient();
  const [{ data: accounts }, activeAccountId] = await Promise.all([
    supabase.from("accounts").select("id, type, businesses(id, name, slug)").returns<AccountRow[]>(),
    getActiveAccountId(),
  ]);

  return (
    <div className="flex flex-col gap-8">
      <div>
        <h1 className="text-xl font-semibold text-[var(--color-text-primary)]">Business</h1>
        <p className="mt-1 text-sm text-[var(--color-text-secondary)]">
          Every account you can act as — your personal account, plus any business you belong to.
          The active one is what Today, Money, and Sell show data for.
        </p>
      </div>

      <div className="flex flex-col gap-2">
        {(accounts ?? []).map((account) => {
          const isActive = account.id === activeAccountId;
          return (
            <Card key={account.id} className="flex items-center justify-between px-4 py-3">
              <div>
                <p className="text-sm font-medium text-[var(--color-text-primary)]">
                  {account.type === "personal" ? "Personal account" : account.businesses?.name}
                </p>
                <p className="text-xs text-[var(--color-text-tertiary)]">
                  {account.type === "personal" ? "Just you" : `@${account.businesses?.slug}`}
                </p>
              </div>
              <div className="flex items-center gap-3">
                <StatusBadge label={account.type} tone="neutral" />
                {isActive ? (
                  <StatusBadge label="Active" tone="brand" />
                ) : (
                  <form action={switchActiveAccount}>
                    <input type="hidden" name="accountId" value={account.id} />
                    <button
                      type="submit"
                      className="text-xs font-medium text-[var(--color-text-tertiary)] hover:underline"
                    >
                      Switch to this
                    </button>
                  </form>
                )}
              </div>
            </Card>
          );
        })}
      </div>

      <div className="grid grid-cols-1 gap-3 sm:grid-cols-2">
        {HUB_LINKS.map((link) => (
          <Link key={link.href} href={link.href} className="block">
            <Card interactive className="h-full p-4">
              <p className="text-sm font-semibold text-[var(--color-text-primary)]">{link.label}</p>
              <p className="mt-1 text-xs text-[var(--color-text-tertiary)]">{link.description}</p>
            </Card>
          </Link>
        ))}
      </div>

      <Card className="p-4">
        <h2 className="mb-3 text-xs font-semibold tracking-[0.1em] text-[var(--color-text-secondary)]">
          START A BUSINESS
        </h2>
        <CreateBusinessForm />
      </Card>
    </div>
  );
}
