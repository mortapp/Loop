import { NextResponse } from "next/server";
import type Anthropic from "@anthropic-ai/sdk";
import { AI_MODEL, AI_SYSTEM_PROMPT, createAiClient, isAiConfigured } from "@/lib/ai/client";
import { AI_TOOLS, executeTool } from "@/lib/ai/tools";
import { resolveAiRequest } from "@/lib/ai/auth";
import { verifyAiConfirmationToken } from "@/lib/ai/confirmation-token";
import { userSafeServerError } from "@/lib/user-safe-error";
import type { ChatResponseBody } from "../chat/route";

type ConfirmRequestBody = {
  messages: Anthropic.MessageParam[];
  toolUseId: string;
  confirmationToken: string;
  approve: boolean;
  accountId?: string;
};

/**
 * Runs (or declines) a tool call the human just confirmed/denied, then
 * asks Claude for one follow-up turn so the conversation stays coherent.
 * Only ever called after src/app/api/ai/chat/route.ts returned a
 * `tool_confirmation` — never executes without that round trip.
 */
export async function POST(request: Request) {
  if (!isAiConfigured()) {
    return NextResponse.json<ChatResponseBody>(
      { type: "error", error: "AI is not configured (ANTHROPIC_API_KEY unset)." },
      { status: 503 },
    );
  }

  let body: ConfirmRequestBody;
  try {
    body = (await request.json()) as ConfirmRequestBody;
  } catch {
    return NextResponse.json<ChatResponseBody>(
      { type: "error", error: "Invalid request." },
      { status: 400 },
    );
  }
  const { messages, toolUseId, confirmationToken, approve } = body;

  if (
    !Array.isArray(messages) ||
    messages.length === 0 ||
    messages.length > 100 ||
    typeof toolUseId !== "string" ||
    toolUseId.length === 0 ||
    toolUseId.length > 200 ||
    typeof approve !== "boolean" ||
    (body.accountId !== undefined && typeof body.accountId !== "string")
  ) {
    return NextResponse.json<ChatResponseBody>(
      { type: "error", error: "Invalid confirmation request." },
      { status: 400 },
    );
  }

  const auth = await resolveAiRequest(request, body.accountId);
  if ("error" in auth) {
    return NextResponse.json<ChatResponseBody>(
      { type: "error", error: auth.error },
      { status: auth.status },
    );
  }
  const { supabase, userId, accountId } = auth;

  const lastAssistant = messages[messages.length - 1];
  const toolUseBlock =
    lastAssistant?.role === "assistant" && Array.isArray(lastAssistant.content)
      ? lastAssistant.content.find(
          (block): block is Anthropic.ToolUseBlock =>
            block.type === "tool_use" && block.id === toolUseId,
        )
      : undefined;

  if (!toolUseBlock) {
    return NextResponse.json<ChatResponseBody>(
      { type: "error", error: "No matching tool call." },
      { status: 400 },
    );
  }

  if (typeof confirmationToken !== "string") {
    return NextResponse.json<ChatResponseBody>(
      { type: "error", error: "This pending action is no longer valid. Ask LOOP again." },
      { status: 400 },
    );
  }

  const verified = verifyAiConfirmationToken(confirmationToken, {
    userId,
    accountId,
    toolUseId,
    toolName: toolUseBlock.name,
    input: toolUseBlock.input as Record<string, unknown>,
  });
  if (!verified.ok) {
    return NextResponse.json<ChatResponseBody>(
      {
        type: "error",
        error: "This pending action belongs to another session or account. Ask LOOP again.",
      },
      { status: 409 },
    );
  }

  let toolResultContent: string;
  let isError = false;

  if (!approve) {
    toolResultContent = "The user declined this action.";
  } else {
    const result = await executeTool(
      supabase,
      accountId,
      userId,
      toolUseBlock.name,
      toolUseBlock.input as Record<string, unknown>,
      verified.confirmationId,
    );
    if ("error" in result) {
      toolResultContent = result.error;
      isError = true;
    } else {
      toolResultContent = result.summary;
    }
  }

  const messagesWithResult: Anthropic.MessageParam[] = [
    ...messages,
    {
      role: "user",
      content: [
        {
          type: "tool_result",
          tool_use_id: toolUseId,
          content: toolResultContent,
          is_error: isError,
        },
      ],
    },
  ];

  const client = createAiClient();

  let response: Anthropic.Message;
  try {
    response = await client.messages.create({
      model: AI_MODEL,
      max_tokens: 1024,
      system: AI_SYSTEM_PROMPT,
      tools: AI_TOOLS,
      messages: messagesWithResult,
    });
  } catch (error) {
    const message = userSafeServerError(
      "ai:confirm-provider",
      error,
      "LOOP AI is temporarily unavailable. Please try again.",
    );
    return NextResponse.json<ChatResponseBody>({ type: "error", error: message }, { status: 502 });
  }

  if (response.stop_reason === "refusal") {
    return NextResponse.json<ChatResponseBody>(
      { type: "error", error: "That request was declined." },
      { status: 200 },
    );
  }

  const updatedMessages: Anthropic.MessageParam[] = [
    ...messagesWithResult,
    { role: "assistant", content: response.content },
  ];

  const text = response.content
    .filter((block): block is Anthropic.TextBlock => block.type === "text")
    .map((block) => block.text)
    .join("\n");

  return NextResponse.json<ChatResponseBody>({ type: "text", text, messages: updatedMessages });
}
