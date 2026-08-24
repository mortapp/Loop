import { isAiConfigured } from "@/lib/ai/client";
import { LedgerHero, LedgerPageIntro } from "@/components/ui/ledger";
import { ChatUi } from "./chat-ui";

export default function AiPage() {
  const configured = isAiConfigured();

  return (
    <div className="flex flex-col gap-8">
      <LedgerPageIntro title="Ask LOOP" subtitle="Private counsel for your value in motion." />

      {configured ? (
        <ChatUi />
      ) : (
        <LedgerHero
          eyebrow="Unavailable"
          value={
            <p
              className="text-2xl text-[var(--color-text-primary)]"
              style={{ fontFamily: "var(--font-display)", fontWeight: 600 }}
            >
              Ask LOOP is not available yet.
            </p>
          }
          detail="Your ledger still works normally. This space will remain closed until its private counsel provider is configured."
        />
      )}
    </div>
  );
}
