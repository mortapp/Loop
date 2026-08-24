import Link from "next/link";
import { LedgerPageIntro, LedgerRow } from "@/components/ui/ledger";

const LINKS = [
  { href: "/profile", label: "Profile", description: "Name, email, and account memberships." },
  {
    href: "/business",
    label: "Accounts & businesses",
    description: "Switch account, or start a business.",
  },
  {
    href: "/settings/personalization",
    label: "Appearance",
    description: "Use the system, dark, or light theme.",
  },
  { href: "/help", label: "Help", description: "Learn how LOOP works." },
];

export default function SettingsPage() {
  return (
    <div className="flex flex-col gap-8">
      <LedgerPageIntro title="Account" subtitle="Your identity and LOOP preferences." />

      <div>
        {LINKS.map((link) => (
          <Link key={link.href} href={link.href} className="block">
            <LedgerRow>
              <div>
                <p className="text-sm font-semibold text-[var(--color-text-primary)]">
                  {link.label}
                </p>
                <p className="mt-0.5 text-xs text-[var(--color-text-tertiary)]">
                  {link.description}
                </p>
              </div>
              <span aria-hidden className="text-[var(--color-text-tertiary)]">
                →
              </span>
            </LedgerRow>
          </Link>
        ))}
      </div>
    </div>
  );
}
