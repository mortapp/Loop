"use client";

import { useState } from "react";
import type Anthropic from "@anthropic-ai/sdk";
import type { ChatResponseBody } from "@/app/api/ai/chat/route";
import { LoopSeal } from "@/components/ui/loop-seal";
import { formInputClass, formButtonClass } from "@/components/ui/form-styles";

type DisplayEntry = { role: "user" | "assistant"; text: string };

type PendingConfirmation = {
  toolUseId: string;
  toolName: string;
  input: Record<string, unknown>;
};

function extractText(content: Anthropic.MessageParam["content"]): string {
  if (typeof content === "string") return content;
  return content
    .filter((block): block is Anthropic.TextBlockParam => block.type === "text")
    .map((block) => block.text)
    .join("\n");
}

function describeToolCall(name: string, input: Record<string, unknown>): string {
  if (name === "create_action") {
    return `Add to Today: "${String(input.title ?? "")}"`;
  }
  if (name === "log_money_event") {
    return `Log ${String(input.kind ?? "")} of $${Number(input.amountDollars ?? 0).toFixed(2)}${
      input.description ? ` — ${String(input.description)}` : ""
    }`;
  }
  return `${name}(${JSON.stringify(input)})`;
}

export function ChatUi() {
  const [rawMessages, setRawMessages] = useState<Anthropic.MessageParam[]>([]);
  const [log, setLog] = useState<DisplayEntry[]>([]);
  const [pending, setPending] = useState<PendingConfirmation | null>(null);
  const [input, setInput] = useState("");
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  function handleChatResponse(body: ChatResponseBody) {
    if (body.type === "error") {
      setError(body.error);
      return;
    }
    setRawMessages(body.messages);
    const lastAssistant = body.messages[body.messages.length - 1];
    const text = lastAssistant ? extractText(lastAssistant.content) : "";
    if (text) {
      setLog((prev) => [...prev, { role: "assistant", text }]);
    }
    if (body.type === "tool_confirmation") {
      setPending({ toolUseId: body.toolUseId, toolName: body.toolName, input: body.input });
    }
  }

  async function sendMessage() {
    const text = input.trim();
    if (!text || busy) return;
    setError(null);
    setInput("");
    setLog((prev) => [...prev, { role: "user", text }]);
    setBusy(true);

    const nextMessages: Anthropic.MessageParam[] = [...rawMessages, { role: "user", content: text }];
    try {
      const res = await fetch("/api/ai/chat", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ messages: nextMessages }),
      });
      handleChatResponse((await res.json()) as ChatResponseBody);
    } catch {
      setError("Request failed.");
    } finally {
      setBusy(false);
    }
  }

  async function respondToConfirmation(approve: boolean) {
    if (!pending || busy) return;
    setBusy(true);
    setError(null);
    try {
      const res = await fetch("/api/ai/confirm", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ messages: rawMessages, toolUseId: pending.toolUseId, approve }),
      });
      setPending(null);
      handleChatResponse((await res.json()) as ChatResponseBody);
    } catch {
      setError("Request failed.");
    } finally {
      setBusy(false);
    }
  }

  return (
    <div className="flex flex-col gap-4">
      <div className="flex min-h-[16rem] flex-col gap-3 rounded-[var(--radius-lg)] border border-[var(--color-border-subtle)] bg-[var(--color-surface)] p-4">
        {log.length === 0 ? (
          <p className="text-sm text-[var(--color-text-tertiary)]">
            Ask about your day, or tell it something to log — e.g. &quot;remind me to call the
            supplier tomorrow&quot; or &quot;I spent $40 on packing tape&quot;.
          </p>
        ) : (
          log.map((entry, i) =>
            entry.role === "user" ? (
              <div
                key={i}
                className="max-w-[80%] self-end rounded-[var(--radius-md)] bg-[var(--color-brand)] px-3 py-2 text-sm text-[var(--color-on-accent)]"
              >
                {entry.text}
              </div>
            ) : (
              <div key={i} className="flex max-w-[80%] items-start gap-2 self-start">
                <LoopSeal size={16} className="mt-1 shrink-0 opacity-70" />
                <p className="rounded-[var(--radius-md)] bg-[var(--color-bg-secondary)] px-3 py-2 text-sm text-[var(--color-text-primary)]">
                  {entry.text}
                </p>
              </div>
            ),
          )
        )}

        {pending ? (
          <div className="self-start rounded-[var(--radius-md)] border border-[var(--color-border-strong)] bg-[var(--color-warning-soft)] px-3 py-2 text-sm">
            <p className="font-medium text-[var(--color-warning-text)]">
              {describeToolCall(pending.toolName, pending.input)}
            </p>
            <div className="mt-2 flex gap-2">
              <button
                onClick={() => respondToConfirmation(true)}
                disabled={busy}
                className="rounded-[var(--radius-sm)] bg-[var(--color-brand)] px-3 py-1 text-xs font-medium text-[var(--color-on-accent)] disabled:opacity-50"
              >
                Confirm
              </button>
              <button
                onClick={() => respondToConfirmation(false)}
                disabled={busy}
                className="rounded-[var(--radius-sm)] border border-[var(--color-border-strong)] px-3 py-1 text-xs font-medium text-[var(--color-text-secondary)] disabled:opacity-50"
              >
                Decline
              </button>
            </div>
          </div>
        ) : null}
      </div>

      {error ? <p className="text-sm text-[var(--color-danger-text)]">{error}</p> : null}

      <form
        onSubmit={(e) => {
          e.preventDefault();
          sendMessage();
        }}
        className="flex items-center gap-2"
      >
        <input
          value={input}
          onChange={(e) => setInput(e.target.value)}
          disabled={busy || Boolean(pending)}
          placeholder={pending ? "Respond to the pending action above first…" : "Message LOOP…"}
          className={`flex-1 ${formInputClass}`}
        />
        <button type="submit" disabled={busy || Boolean(pending) || !input.trim()} className={formButtonClass}>
          Send
        </button>
      </form>
    </div>
  );
}
