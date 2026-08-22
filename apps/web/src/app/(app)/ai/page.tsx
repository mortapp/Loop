import { isAiConfigured } from "@/lib/ai/client";
import { Card } from "@/components/ui/card";
import { ChatUi } from "./chat-ui";

export default function AiPage() {
  const configured = isAiConfigured();

  return (
    <div className="flex flex-col gap-6">
      <div>
        <h1
          className="text-2xl tracking-[0.08em] text-[var(--color-text-primary)]"
          style={{ fontFamily: "var(--font-display)", fontWeight: 600 }}
        >
          Ask LOOP
        </h1>
        <p className="mt-1 text-sm text-[var(--color-text-secondary)]">
          What should we work through? Nothing here executes without you approving it first.
        </p>
      </div>

      {configured ? (
        <ChatUi />
      ) : (
        <Card className="border-dashed p-8">
          <p className="text-sm text-[var(--color-text-secondary)]">
            AI isn&apos;t configured yet — set <code>ANTHROPIC_API_KEY</code> (and optionally{" "}
            <code>ANTHROPIC_MODEL</code>, defaults to <code>claude-opus-5</code>) to enable it.
            See docs/KNOWN_ISSUES.md.
          </p>
        </Card>
      )}
    </div>
  );
}
