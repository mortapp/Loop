import { createClient } from "@/lib/supabase/server";
import { getCurrentProfile, initialsFor } from "@/lib/profile";
import { getActiveAccountSummary } from "@/lib/active-account";
import { Card } from "@/components/ui/card";
import { ProfileForm } from "./profile-form";

type MembershipRow = {
  id: string;
  type: "personal" | "business";
  businesses: { name: string } | null;
};

export default async function ProfilePage() {
  const supabase = await createClient();
  const [profile, activeAccount, { data: memberships }] = await Promise.all([
    getCurrentProfile(),
    getActiveAccountSummary(),
    supabase.from("accounts").select("id, type, businesses(name)").returns<MembershipRow[]>(),
  ]);

  if (!profile) {
    return null; // AppLayout already redirects unauthenticated users to /sign-in
  }

  const initials = initialsFor(profile.displayName, profile.email);

  return (
    <div className="flex flex-col gap-6">
      <h1 className="text-xl font-semibold text-[var(--color-text-primary)]">Profile</h1>

      <Card className="flex items-center gap-4 p-4">
        <span
          aria-hidden
          className="flex h-14 w-14 shrink-0 items-center justify-center rounded-full bg-[var(--color-brand)] text-lg font-semibold text-[var(--color-on-accent)]"
        >
          {initials}
        </span>
        <div className="min-w-0">
          <p className="truncate text-sm font-medium text-[var(--color-text-primary)]">
            {profile.displayName || profile.email}
          </p>
          <p className="truncate text-xs text-[var(--color-text-tertiary)]">{profile.email}</p>
        </div>
      </Card>

      <Card className="flex flex-col gap-4 p-4">
        <h2 className="text-xs font-semibold tracking-[0.1em] text-[var(--color-text-secondary)]">
          DISPLAY NAME
        </h2>
        <ProfileForm initialDisplayName={profile.displayName ?? ""} />
      </Card>

      <Card className="flex flex-col gap-3 p-4">
        <h2 className="text-xs font-semibold tracking-[0.1em] text-[var(--color-text-secondary)]">
          EMAIL
        </h2>
        <p className="text-sm text-[var(--color-text-primary)]">{profile.email}</p>
        <p className="text-xs text-[var(--color-text-tertiary)]">
          Changing your sign-in email isn&apos;t supported yet.
        </p>
      </Card>

      <Card className="flex flex-col gap-3 p-4">
        <h2 className="text-xs font-semibold tracking-[0.1em] text-[var(--color-text-secondary)]">
          ACCOUNTS
        </h2>
        <div className="flex flex-col gap-2">
          {(memberships ?? []).map((m) => {
            const label = m.type === "personal" ? "Personal account" : (m.businesses?.name ?? "Business");
            const isActive = m.id === activeAccount?.id;
            return (
              <div key={m.id} className="flex items-center justify-between text-sm">
                <span className="text-[var(--color-text-primary)]">{label}</span>
                {isActive ? (
                  <span className="text-xs font-medium text-[var(--color-brand-text)]">Active</span>
                ) : null}
              </div>
            );
          })}
        </div>
      </Card>
    </div>
  );
}
