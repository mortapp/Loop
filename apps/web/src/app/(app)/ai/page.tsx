import { isAiConfigured } from "@/lib/ai/client";
import { ChatUi } from "./chat-ui";

export default function AiPage() {
  const configured = isAiConfigured();

  return (
    <div className="flex flex-col gap-6">
      <div>
        <h1 className="text-xl font-semibold text-zinc-950 dark:text-zinc-50">AI</h1>
        <p className="mt-1 text-sm text-zinc-500 dark:text-zinc-400">
          A tool registry over Today and Money, gated by an explicit confirmation step before
          anything actually runs — nothing here executes without you approving it first.
        </p>
      </div>

      {configured ? (
        <ChatUi />
      ) : (
        <div className="rounded-2xl border border-dashed border-zinc-300 bg-white p-8 dark:border-zinc-700 dark:bg-zinc-950">
          <p className="text-sm text-zinc-500 dark:text-zinc-400">
            AI isn&apos;t configured yet — set <code>ANTHROPIC_API_KEY</code> (and optionally{" "}
            <code>ANTHROPIC_MODEL</code>, defaults to <code>claude-opus-5</code>) to enable it.
            See docs/KNOWN_ISSUES.md.
          </p>
        </div>
      )}
    </div>
  );
}
