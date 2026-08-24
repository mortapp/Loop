import Link from "next/link";
import type { OpportunityStage, QuoteStatus } from "@loop/contracts";
import { createClient } from "@/lib/supabase/server";
import { getActiveAccountId } from "@/lib/active-account";
import { Amount } from "@/components/ui/amount";
import { LedgerHero, LedgerPageIntro, LedgerRow, LedgerSectionLabel } from "@/components/ui/ledger";
import { StatusBadge } from "@/components/ui/status-badge";
import { CreateBusinessForm } from "./create-business-form";
import { switchActiveAccount } from "./actions";

type AccountRow = {
  id: string;
  type: "personal" | "business";
  businesses: { id: string; name: string; slug: string } | null;
};

type ContactRow = {
  id: string;
  display_name: string;
  company: string | null;
};

type OpportunityRow = {
  id: string;
  title: string;
  stage: OpportunityStage;
  estimated_value_cents: number | null;
  contacts: { id: string; display_name: string } | null;
};

type QuoteRow = {
  id: string;
  quote_number: string;
  status: QuoteStatus;
  total_cents: number;
  currency: string;
  contacts: { id: string; display_name: string } | null;
};

export default async function BusinessPage() {
  const supabase = await createClient();
  const [{ data: accounts }, activeAccountId] = await Promise.all([
    supabase
      .from("accounts")
      .select("id, type, businesses(id, name, slug)")
      .returns<AccountRow[]>(),
    getActiveAccountId(),
  ]);

  const [{ data: contacts }, { data: opportunities }, { data: quotes }] = await Promise.all([
    activeAccountId
      ? supabase
          .from("contacts")
          .select("id, display_name, company")
          .eq("account_id", activeAccountId)
          .order("created_at", { ascending: false })
          .limit(3)
          .returns<ContactRow[]>()
      : Promise.resolve({ data: [] as ContactRow[] }),
    activeAccountId
      ? supabase
          .from("opportunities")
          .select("id, title, stage, estimated_value_cents, contacts(id, display_name)")
          .eq("account_id", activeAccountId)
          .in("stage", ["new", "qualifying", "quoted", "negotiating"])
          .order("created_at", { ascending: false })
          .limit(3)
          .returns<OpportunityRow[]>()
      : Promise.resolve({ data: [] as OpportunityRow[] }),
    activeAccountId
      ? supabase
          .from("quotes")
          .select("id, quote_number, status, total_cents, currency, contacts(id, display_name)")
          .eq("account_id", activeAccountId)
          .order("created_at", { ascending: false })
          .limit(3)
          .returns<QuoteRow[]>()
      : Promise.resolve({ data: [] as QuoteRow[] }),
  ]);

  const activeAccount = (accounts ?? []).find((account) => account.id === activeAccountId);
  const activeLabel =
    activeAccount?.type === "business"
      ? (activeAccount.businesses?.name ?? "Business")
      : "Personal";

  return (
    <div className="flex flex-col gap-8">
      <LedgerPageIntro title="Business" subtitle={`People, work, and quotes for ${activeLabel}.`} />

      <LedgerHero
        eyebrow="Next"
        value={
          <p
            className="text-2xl text-[var(--color-text-primary)]"
            style={{ fontFamily: "var(--font-display)", fontWeight: 600 }}
          >
            Turn work into a clear quote.
          </p>
        }
        detail="LOOP calculates the total and keeps its status honest."
        action={
          <Link
            href="/business/quotes"
            className="inline-flex rounded-[var(--radius-sm)] bg-[var(--color-brand)] px-4 py-2 text-sm font-semibold text-[var(--color-on-accent)] transition-opacity hover:opacity-90"
          >
            Create quote
          </Link>
        }
      />

      <section>
        <LedgerSectionLabel trailing={<QuietLink href="/business/contacts">See all</QuietLink>}>
          People
        </LedgerSectionLabel>
        <div className="mt-1">
          {(contacts ?? []).length === 0 ? (
            <LinkedEmptyRow
              href="/business/contacts"
              title="No people yet"
              detail="Add a customer before creating a quote."
            />
          ) : (
            (contacts ?? []).map((contact) => (
              <Link key={contact.id} href="/business/contacts" className="block">
                <LedgerRow>
                  <div>
                    <p className="text-sm font-semibold text-[var(--color-text-primary)]">
                      {contact.display_name}
                    </p>
                    {contact.company ? (
                      <p className="mt-0.5 text-xs text-[var(--color-text-tertiary)]">
                        {contact.company}
                      </p>
                    ) : null}
                  </div>
                  <span aria-hidden className="text-[var(--color-text-tertiary)]">
                    →
                  </span>
                </LedgerRow>
              </Link>
            ))
          )}
        </div>
      </section>

      <section>
        <LedgerSectionLabel
          trailing={<QuietLink href="/business/opportunities">See all</QuietLink>}
        >
          Work
        </LedgerSectionLabel>
        <div className="mt-1">
          {(opportunities ?? []).length === 0 ? (
            <LinkedEmptyRow
              href="/business/opportunities"
              title="No active work"
              detail="Start with a person or create an opportunity."
            />
          ) : (
            (opportunities ?? []).map((work) => (
              <Link key={work.id} href="/business/opportunities" className="block">
                <LedgerRow>
                  <div>
                    <p className="text-sm font-semibold text-[var(--color-text-primary)]">
                      {work.title}
                    </p>
                    <p className="mt-0.5 text-xs text-[var(--color-text-tertiary)]">
                      {[work.contacts?.display_name, work.stage].filter(Boolean).join(" · ")}
                    </p>
                  </div>
                  {work.estimated_value_cents === null ? null : (
                    <Amount cents={work.estimated_value_cents} className="font-medium" />
                  )}
                </LedgerRow>
              </Link>
            ))
          )}
        </div>
      </section>

      <section>
        <LedgerSectionLabel trailing={<QuietLink href="/business/quotes">See all</QuietLink>}>
          Quotes
        </LedgerSectionLabel>
        <div className="mt-1">
          {(quotes ?? []).length === 0 ? (
            <LinkedEmptyRow
              href="/business/quotes"
              title="No quotes yet"
              detail="Create one when the work is clear."
            />
          ) : (
            (quotes ?? []).map((quote) => (
              <Link key={quote.id} href="/business/quotes" className="block">
                <LedgerRow>
                  <div>
                    <p className="text-sm font-semibold text-[var(--color-text-primary)]">
                      {quote.contacts?.display_name ?? quote.quote_number}
                    </p>
                    <p className="mt-0.5 text-xs text-[var(--color-text-tertiary)]">
                      {quote.quote_number} · {quote.status}
                    </p>
                  </div>
                  <Amount
                    cents={quote.total_cents}
                    currency={quote.currency}
                    className="font-medium"
                  />
                </LedgerRow>
              </Link>
            ))
          )}
        </div>
      </section>

      <Link href="/business/leads" className="block">
        <LedgerRow>
          <div>
            <p className="text-sm font-semibold text-[var(--color-text-primary)]">Leads</p>
            <p className="mt-0.5 text-xs text-[var(--color-text-tertiary)]">
              Early interest that is not active work yet.
            </p>
          </div>
          <span aria-hidden className="text-[var(--color-text-tertiary)]">
            →
          </span>
        </LedgerRow>
      </Link>

      <details className="group border-t border-[var(--color-border-subtle)] pt-4">
        <summary className="cursor-pointer text-sm text-[var(--color-text-tertiary)] hover:text-[var(--color-text-secondary)]">
          Manage accounts
        </summary>
        <div className="mt-4 flex flex-col gap-2">
          {(accounts ?? []).map((account) => {
            const isActive = account.id === activeAccountId;
            return (
              <LedgerRow key={account.id}>
                <div>
                  <p className="text-sm font-medium text-[var(--color-text-primary)]">
                    {account.type === "personal" ? "Personal account" : account.businesses?.name}
                  </p>
                  <p className="text-xs text-[var(--color-text-tertiary)]">
                    {account.type === "personal" ? "Just you" : `@${account.businesses?.slug}`}
                  </p>
                </div>
                {isActive ? (
                  <StatusBadge label="Active" tone="brand" />
                ) : (
                  <form action={switchActiveAccount}>
                    <input type="hidden" name="accountId" value={account.id} />
                    <button
                      type="submit"
                      className="text-xs font-medium text-[var(--color-brand-text)] hover:opacity-70"
                    >
                      Switch
                    </button>
                  </form>
                )}
              </LedgerRow>
            );
          })}
          <div className="mt-4 max-w-xl">
            <CreateBusinessForm />
          </div>
        </div>
      </details>
    </div>
  );
}

function QuietLink({ href, children }: { href: string; children: React.ReactNode }) {
  return (
    <Link
      href={href}
      className="text-xs font-medium text-[var(--color-brand-text)] hover:opacity-70"
    >
      {children}
    </Link>
  );
}

function LinkedEmptyRow({ href, title, detail }: { href: string; title: string; detail: string }) {
  return (
    <Link href={href} className="block">
      <LedgerRow>
        <div>
          <p className="text-sm font-semibold text-[var(--color-text-primary)]">{title}</p>
          <p className="mt-0.5 text-xs text-[var(--color-text-tertiary)]">{detail}</p>
        </div>
        <span aria-hidden className="text-[var(--color-text-tertiary)]">
          →
        </span>
      </LedgerRow>
    </Link>
  );
}
