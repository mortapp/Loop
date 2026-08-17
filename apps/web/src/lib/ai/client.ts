import Anthropic from "@anthropic-ai/sdk";

/**
 * ALWAYS claude-opus-5 unless a deployer explicitly overrides it via
 * ANTHROPIC_MODEL — see the claude-api skill: never downgrade the default
 * for cost, that's a deployer decision, not ours.
 */
export const AI_MODEL = process.env.ANTHROPIC_MODEL ?? "claude-opus-5";

export function isAiConfigured(): boolean {
  return Boolean(process.env.ANTHROPIC_API_KEY);
}

/** Throws if ANTHROPIC_API_KEY is unset — callers must check isAiConfigured() first. */
export function createAiClient(): Anthropic {
  return new Anthropic({ apiKey: process.env.ANTHROPIC_API_KEY });
}

export const AI_SYSTEM_PROMPT = `You are LOOP's assistant. LOOP is a unified value operating system with three engines: MAKE (QuoteCloser — leads/opportunities/quotes), PROTECT (ReturnGuard — purchases/returns/warranties), and RECOVER (ResellLens — valuations/listings/sales), all sharing one Today action queue and one Money ledger.

You can propose two safe, reversible actions via tools: adding a Today task, or logging a manual money ledger entry. Every tool call you make is shown to the user for explicit confirmation before it runs — you never execute anything directly. When a tool call is declined, accept that and move on rather than repeating the same proposal.

Keep responses concise and conversational.`;
