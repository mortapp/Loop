import Link from "next/link";
import type { Contact } from "@loop/contracts";
import { createClient } from "@/lib/supabase/server";
import { getActiveAccountId } from "@/lib/active-account";
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
        <Link href="/business" className="text-xs text-zinc-500 hover:underline dark:text-zinc-400">
          ← Business
        </Link>
        <h1 className="mt-1 text-xl font-semibold text-zinc-950 dark:text-zinc-50">Contacts</h1>
        <p className="mt-1 text-sm text-zinc-500 dark:text-zinc-400">
          Customers, vendors, and anyone else you deal with — shared across MAKE, PROTECT, and
          RECOVER.
        </p>
      </div>

      <div className="rounded-2xl border border-zinc-200 bg-white p-4 dark:border-zinc-800 dark:bg-zinc-950">
        <CreateContactForm />
      </div>

      <ul className="flex flex-col gap-2">
        {(contacts ?? []).length === 0 ? (
          <p className="text-sm text-zinc-500 dark:text-zinc-400">No contacts yet.</p>
        ) : (
          (contacts ?? []).map((contact) => (
            <li
              key={contact.id}
              className="flex items-center justify-between rounded-xl border border-zinc-200 bg-white px-4 py-3 dark:border-zinc-800 dark:bg-zinc-950"
            >
              <div>
                <p className="text-sm font-medium text-zinc-950 dark:text-zinc-50">
                  {contact.display_name}
                </p>
                <p className="text-xs text-zinc-500 dark:text-zinc-400">
                  {[contact.company, contact.email, contact.phone].filter(Boolean).join(" · ") ||
                    "No details"}
                </p>
              </div>
            </li>
          ))
        )}
      </ul>
    </div>
  );
}
