"use client";

import { useState } from "react";
import type Anthropic from "@anthropic-ai/sdk";
import type { ChatResponseBody } from "@/app/api/ai/chat/route";

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
      <div className="flex min-h-[16rem] flex-col gap-3 rounded-2xl border border-zinc-200 bg-white p-4 dark:border-zinc-800 dark:bg-zinc-950">
        {log.length === 0 ? (
          <p className="text-sm text-zinc-500 dark:text-zinc-400">
            Ask about your day, or tell it something to log — e.g. &quot;remind me to call the
            supplier tomorrow&quot; or &quot;I spent $40 on packing tape&quot;.
          </p>
        ) : (
          log.map((entry, i) => (
            <div
              key={i}
              className={`max-w-[80%] rounded-xl px-3 py-2 text-sm ${
                entry.role === "user"
                  ? "self-end bg-zinc-950 text-white dark:bg-zinc-50 dark:text-zinc-950"
                  : "self-start bg-zinc-100 text-zinc-950 dark:bg-zinc-900 dark:text-zinc-50"
              }`}
            >
              {entry.text}
            </div>
          ))
        )}

        {pending ? (
          <div className="self-start rounded-xl border border-amber-300 bg-amber-50 px-3 py-2 text-sm dark:border-amber-800 dark:bg-amber-950">
            <p className="font-medium text-amber-900 dark:text-amber-200">
              {describeToolCall(pending.toolName, pending.input)}
            </p>
            <div className="mt-2 flex gap-2">
              <button
                onClick={() => respondToConfirmation(true)}
                disabled={busy}
                className="rounded-lg bg-zinc-950 px-3 py-1 text-xs font-medium text-white disabled:opacity-50 dark:bg-zinc-50 dark:text-zinc-950"
              >
                Confirm
              </button>
              <button
                onClick={() => respondToConfirmation(false)}
                disabled={busy}
                className="rounded-lg border border-zinc-300 px-3 py-1 text-xs font-medium text-zinc-700 disabled:opacity-50 dark:border-zinc-700 dark:text-zinc-300"
              >
                Decline
              </button>
            </div>
          </div>
        ) : null}
      </div>

      {error ? <p className="text-sm text-red-600 dark:text-red-400">{error}</p> : null}

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
          className="flex-1 rounded-lg border border-zinc-300 bg-white px-3 py-2 text-sm text-zinc-950 outline-none focus:border-zinc-500 disabled:opacity-50 dark:border-zinc-700 dark:bg-zinc-900 dark:text-zinc-50"
        />
        <button
          type="submit"
          disabled={busy || Boolean(pending) || !input.trim()}
          className="rounded-lg bg-zinc-950 px-4 py-2 text-sm font-medium text-white transition-colors hover:bg-zinc-800 disabled:opacity-50 dark:bg-zinc-50 dark:text-zinc-950 dark:hover:bg-zinc-200"
        >
          Send
        </button>
      </form>
    </div>
  );
}
