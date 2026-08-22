import Link from "next/link";
import type { Contact } from "@loop/contracts";
import { createClient } from "@/lib/supabase/server";
import { getActiveAccountId } from "@/lib/active-account";
import { Card } from "@/components/ui/card";
import { EmptyState } from "@/components/ui/empty-state";
import { CreateContactForm } from "./create-contact-form";

export default async function ContactsPage() {
  const accountId = await getActiveAccountId();
  const supabase = await createClient();

  const { data: contacts } = accountId
    ? await supabase
        .from("contacts")
        .select("*")
        .eq("account_id", accountId)
        .order("created_at", { ascending: false })
        .returns<Contact[]>()
    : { data: [] as Contact[] };

  return (
    <div className="flex flex-col gap-6">
      <div>
        <Link href="/business" className="text-xs text-[var(--color-text-tertiary)] hover:underline">
          ← Business
        </Link>
        <h1 className="mt-1 text-xl font-semibold text-[var(--color-text-primary)]">Contacts</h1>
        <p className="mt-1 text-sm text-[var(--color-text-secondary)]">
          Customers, vendors, and anyone else you deal with — shared across MAKE, PROTECT, and
          RECOVER.
        </p>
      </div>

      <Card className="p-4">
        <CreateContactForm />
      </Card>

      <div className="flex flex-col gap-2">
        {(contacts ?? []).length === 0 ? (
          <EmptyState title="No contacts yet" description="Add one above to get started." />
        ) : (
          (contacts ?? []).map((contact) => (
            <Card key={contact.id} className="flex items-center justify-between px-4 py-3">
              <div>
                <p className="text-sm font-medium text-[var(--color-text-primary)]">
                  {contact.display_name}
                </p>
                <p className="text-xs text-[var(--color-text-tertiary)]">
                  {[contact.company, contact.email, contact.phone].filter(Boolean).join(" · ") ||
                    "No details"}
                </p>
              </div>
            </Card>
          ))
        )}
      </div>
    </div>
  );
}
