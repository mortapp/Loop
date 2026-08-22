import { Card } from "@/components/ui/card";

const TOPICS: { title: string; body: string }[] = [
  {
    title: "Getting started",
    body: "LOOP tracks one loop: Earn → Buy → Own → Return or resell → Earn again. Today is your queue of what needs attention right now; Money is the ledger everything else writes to.",
  },
  {
    title: "Today",
    body: "Add anything you need to do. Quote follow-ups, return deadlines, and resale opportunities will start appearing here on their own as those features mature — for now, add items manually.",
  },
  {
    title: "MAKE — Business",
    body: "Contacts → Leads → Opportunities → Quotes. A lead is interest that isn't qualified yet; an opportunity is worth writing a quote for. Quote totals are calculated from real line items, not typed in by hand.",
  },
  {
    title: "PROTECT — Money → Purchases",
    body: "Record what you buy to track return windows and warranties before they expire. Return status moves through initiated → shipped → received → refunded (or denied). A refund posts straight to your Money ledger.",
  },
  {
    title: "RECOVER — Sell",
    body: "Add an item, value it, list it, then record the sale. A completed sale posts to Money as recovered value automatically — you never enter it twice.",
  },
  {
    title: "Account & accounts",
    body: "\"Account\" in LOOP means whichever business or personal ledger is currently active — switch it from the account menu or Business. Your profile (name, email) is separate from which account is active.",
  },
  {
    title: "Troubleshooting",
    body: "If a page looks stuck after an action, refresh — most actions redirect or revalidate automatically, but a slow network can leave a stale view. If something looks wrong with your data specifically, it's real data, not a display bug — check the underlying record (e.g. the purchase or quote) before assuming LOOP miscalculated.",
  },
];

export default function HelpPage() {
  return (
    <div className="flex flex-col gap-6">
      <div>
        <h1 className="text-xl font-semibold text-[var(--color-text-primary)]">Help &amp; Support</h1>
        <p className="mt-1 text-sm text-[var(--color-text-secondary)]">
          LOOP doesn&apos;t have a published Privacy Policy or Terms of Service yet, and there&apos;s no
          support inbox monitored outside this app — this page is what exists today.
        </p>
      </div>

      <div className="flex flex-col gap-3">
        {TOPICS.map((topic) => (
          <Card key={topic.title} className="p-4">
            <h2 className="text-sm font-semibold text-[var(--color-text-primary)]">{topic.title}</h2>
            <p className="mt-1 text-sm text-[var(--color-text-secondary)]">{topic.body}</p>
          </Card>
        ))}
      </div>
    </div>
  );
}
