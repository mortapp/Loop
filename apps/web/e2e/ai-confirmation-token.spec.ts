import { expect, test } from "@playwright/test";
import {
  issueAiConfirmationToken,
  verifyAiConfirmationToken,
} from "../src/lib/ai/confirmation-token";

const identity = {
  userId: "user-a",
  accountId: "account-a",
  toolUseId: "tool-a",
  toolName: "create_action",
  input: { title: "Follow up" },
};

test.describe("AI confirmation token", () => {
  let previousKey: string | undefined;

  test.beforeEach(() => {
    previousKey = process.env.ANTHROPIC_API_KEY;
    process.env.ANTHROPIC_API_KEY = "test-only-confirmation-signing-key";
  });

  test.afterEach(() => {
    if (previousKey === undefined) delete process.env.ANTHROPIC_API_KEY;
    else process.env.ANTHROPIC_API_KEY = previousKey;
  });

  test("accepts the exact user, account, tool, and canonical input", () => {
    const token = issueAiConfirmationToken(identity, 1_000);
    expect(verifyAiConfirmationToken(token, identity, 2_000)).toMatchObject({ ok: true });
    expect(
      verifyAiConfirmationToken(token, { ...identity, input: { title: "Follow up" } }, 2_000),
    ).toMatchObject({ ok: true });
  });

  test("rejects cross-account, altered-input, tampered, and expired confirmations", () => {
    const token = issueAiConfirmationToken(identity, 1_000);

    expect(
      verifyAiConfirmationToken(token, { ...identity, accountId: "account-b" }, 2_000),
    ).toEqual({ ok: false });
    expect(verifyAiConfirmationToken(token, { ...identity, userId: "user-b" }, 2_000)).toEqual({
      ok: false,
    });
    expect(
      verifyAiConfirmationToken(token, { ...identity, toolName: "log_money_event" }, 2_000),
    ).toEqual({ ok: false });
    expect(
      verifyAiConfirmationToken(
        token,
        { ...identity, input: { title: "Different action" } },
        2_000,
      ),
    ).toEqual({ ok: false });
    expect(verifyAiConfirmationToken(`${token}x`, identity, 2_000)).toEqual({ ok: false });
    expect(verifyAiConfirmationToken("", identity, 2_000)).toEqual({ ok: false });
    expect(verifyAiConfirmationToken(token, identity, 31 * 60 * 1000)).toEqual({ ok: false });
  });
});
