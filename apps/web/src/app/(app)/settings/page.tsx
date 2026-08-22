import Link from "next/link";
import { Card } from "@/components/ui/card";

const SECTIONS: { title: string; links: { href: string; label: string; description: string }[] }[] = [
  {
    title: "ACCOUNT",
    links: [
      { href: "/profile", label: "Profile", description: "Name, email, and account memberships." },
      { href: "/business", label: "Accounts & businesses", description: "Switch account, or start a business." },
    ],
  },
  {
    title: "APPEARANCE",
    links: [
      { href: "/settings/personalization", label: "Personalization", description: "Theme — system, dark, or light." },
    ],
  },
  {
    title: "ABOUT",
    links: [{ href: "/help", label: "Help & Support", description: "How to use LOOP." }],
  },
];

export default function SettingsPage() {
  return (
    <div className="flex flex-col gap-8">
      <h1 className="text-xl font-semibold text-[var(--color-text-primary)]">Settings</h1>

      {SECTIONS.map((section) => (
        <div key={section.title} className="flex flex-col gap-2">
          <h2 className="text-xs font-semibold tracking-[0.1em] text-[var(--color-text-secondary)]">
            {section.title}
          </h2>
          <div className="flex flex-col gap-2">
            {section.links.map((link) => (
              <Link key={link.href} href={link.href} className="block">
                <Card interactive className="flex items-center justify-between p-4">
                  <div>
                    <p className="text-sm font-medium text-[var(--color-text-primary)]">{link.label}</p>
                    <p className="text-xs text-[var(--color-text-tertiary)]">{link.description}</p>
                  </div>
                  <span aria-hidden className="text-[var(--color-text-tertiary)]">
                    →
                  </span>
                </Card>
              </Link>
            ))}
          </div>
        </div>
      ))}
    </div>
  );
}
