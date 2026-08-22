import { NextResponse } from "next/server";
import type Anthropic from "@anthropic-ai/sdk";
import { AI_MODEL, AI_SYSTEM_PROMPT, createAiClient, isAiConfigured } from "@/lib/ai/client";
import { AI_TOOLS } from "@/lib/ai/tools";
import { resolveAiRequest } from "@/lib/ai/auth";

export type ChatResponseBody =
  | { type: "text"; text: string; messages: Anthropic.MessageParam[] }
  | {
      type: "tool_confirmation";
      toolUseId: string;
      toolName: string;
      input: Record<string, unknown>;
      messages: Anthropic.MessageParam[];
    }
  | { type: "error"; error: string };

/**
 * One non-streaming turn of the AI chat. Never executes a tool itself —
 * a `tool_use` stop is returned to the client as a pending confirmation;
 * .../confirm/route.ts is what actually runs it, only after the human
 * approves. See docs/DECISIONS.md for why (Phase 8: tool registry +
 * confirmation system + safe actions).
 */
export async function POST(request: Request) {
  if (!isAiConfigured()) {
    return NextResponse.json<ChatResponseBody>(
      { type: "error", error: "AI is not configured (ANTHROPIC_API_KEY unset)." },
      { status: 503 },
    );
  }

  const body = (await request.json()) as {
    messages?: Anthropic.MessageParam[];
    accountId?: string;
  };
  const messages = body.messages ?? [];
  if (messages.length === 0) {
    return NextResponse.json<ChatResponseBody>({ type: "error", error: "No messages." }, { status: 400 });
  }

  const auth = await resolveAiRequest(request, body.accountId);
  if ("error" in auth) {
    return NextResponse.json<ChatResponseBody>({ type: "error", error: auth.error }, { status: auth.status });
  }

  const client = createAiClient();

  let response: Anthropic.Message;
  try {
    response = await client.messages.create({
      model: AI_MODEL,
      max_tokens: 4096,
      system: AI_SYSTEM_PROMPT,
      tools: AI_TOOLS,
      messages,
    });
  } catch (error) {
    const message = error instanceof Error ? error.message : "AI request failed.";
    return NextResponse.json<ChatResponseBody>({ type: "error", error: message }, { status: 502 });
  }

  // Safety classifiers can decline before any output — check stop_reason
  // before reading content. See the claude-api skill's refusal guidance.
  if (response.stop_reason === "refusal") {
    return NextResponse.json<ChatResponseBody>(
      { type: "error", error: "That request was declined." },
      { status: 200 },
    );
  }

  const updatedMessages: Anthropic.MessageParam[] = [
    ...messages,
    { role: "assistant", content: response.content },
  ];

  if (response.stop_reason === "tool_use") {
    const toolUse = response.content.find((block) => block.type === "tool_use");
    if (toolUse && toolUse.type === "tool_use") {
      return NextResponse.json<ChatResponseBody>({
        type: "tool_confirmation",
        toolUseId: toolUse.id,
        toolName: toolUse.name,
        input: toolUse.input as Record<string, unknown>,
        messages: updatedMessages,
      });
    }
  }

  const text = response.content
    .filter((block): block is Anthropic.TextBlock => block.type === "text")
    .map((block) => block.text)
    .join("\n");

  return NextResponse.json<ChatResponseBody>({ type: "text", text, messages: updatedMessages });
}
