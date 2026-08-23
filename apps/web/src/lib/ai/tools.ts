import type Anthropic from "@anthropic-ai/sdk";
import type { SupabaseClient } from "@supabase/supabase-js";
import { userSafeServerError } from "@/lib/user-safe-error";

/**
 * Phase 8 (AI) tool registry — the "safe actions" Claude is allowed to
 * propose. Every tool here is deliberately a single, reversible,
 * low-stakes write (create_action / log_money_event) — nothing that
 * sends anything externally or touches another party. None of these
 * execute automatically: see src/app/api/ai/chat/route.ts and
 * .../confirm/route.ts for the confirm-before-execute flow.
 */
export const AI_TOOLS: Anthropic.Tool[] = [
  {
    name: "create_action",
    description:
      "Add an item to the user's Today queue (public.actions). Use this when the user asks to be reminded of something, or wants to track a task or follow-up.",
    input_schema: {
      type: "object",
      properties: {
        title: {
          type: "string",
          description: 'Short description of the task, e.g. "Follow up with Jane about the quote".',
        },
      },
      required: ["title"],
      additionalProperties: false,
    },
  },
  {
    name: "log_money_event",
    description:
      "Log a manual entry in the user's money ledger (public.money_events). Use this when the user tells you about money earned, spent, refunded, or a fee, that isn't already tracked by a quote, purchase, or sale elsewhere in LOOP.",
    input_schema: {
      type: "object",
      properties: {
        kind: {
          type: "string",
          enum: ["earn", "spend", "refund", "fee"],
          description: "What kind of money event this is.",
        },
        amountDollars: {
          type: "number",
          description: "The amount in dollars, e.g. 49.99.",
        },
        description: {
          type: "string",
          description: "A short note about what this was for.",
        },
      },
      required: ["kind", "amountDollars"],
      additionalProperties: false,
    },
  },
];

export type ToolExecutionResult = { summary: string } | { error: string };

/**
 * Executes an approved tool call against the given account. Called only
 * after a human has confirmed the action — see .../confirm/route.ts.
 */
export async function executeTool(
  supabase: SupabaseClient,
  accountId: string,
  userId: string | null,
  name: string,
  input: Record<string, unknown>,
): Promise<ToolExecutionResult> {
  switch (name) {
    case "create_action": {
      const title = String(input.title ?? "").trim();
      if (!title) return { error: "Missing title." };

      const { error } = await supabase.from("actions").insert({
        account_id: accountId,
        type: "ai",
        title,
        created_by: userId,
      });
      if (error) {
        return { error: userSafeServerError("ai:add-action", error) };
      }
      return { summary: `Added "${title}" to Today.` };
    }

    case "log_money_event": {
      const kind = String(input.kind ?? "");
      if (!["earn", "spend", "refund", "fee"].includes(kind)) {
        return { error: "Invalid kind." };
      }
      const amountDollars = Number(input.amountDollars);
      const amountCents = Math.round(amountDollars * 100);
      if (!Number.isFinite(amountCents) || amountCents <= 0) {
        return { error: "Invalid amount." };
      }
      const description = input.description ? String(input.description) : null;

      const { error } = await supabase.from("money_events").insert({
        account_id: accountId,
        kind,
        amount_cents: amountCents,
        source_type: "ai",
        description,
        created_by: userId,
      });
      if (error) {
        return { error: userSafeServerError("ai:log-money-event", error) };
      }
      return { summary: `Logged ${kind} of $${amountDollars.toFixed(2)}.` };
    }

    default:
      return { error: `Unknown tool: ${name}` };
  }
}
