import { createHash, createHmac, randomUUID, timingSafeEqual } from "node:crypto";

const CONFIRMATION_TOKEN_VERSION = 1;
const CONFIRMATION_TOKEN_TTL_MS = 30 * 60 * 1000;

type ConfirmationTokenPayload = {
  v: number;
  confirmationId: string;
  userId: string;
  accountId: string;
  toolUseId: string;
  toolName: string;
  inputHash: string;
  issuedAt: number;
  expiresAt: number;
};

type ConfirmationIdentity = {
  userId: string;
  accountId: string;
  toolUseId: string;
  toolName: string;
  input: Record<string, unknown>;
};

export type VerifiedConfirmation = { ok: true; confirmationId: string } | { ok: false };

function signingKey(): string {
  const key = process.env.ANTHROPIC_API_KEY;
  if (!key) throw new Error("AI confirmation signing is unavailable.");
  return key;
}

function canonicalJson(value: unknown): string {
  if (value === null || typeof value !== "object") {
    return JSON.stringify(value) ?? "null";
  }
  if (Array.isArray(value)) {
    return `[${value.map(canonicalJson).join(",")}]`;
  }
  const object = value as Record<string, unknown>;
  return `{${Object.keys(object)
    .sort()
    .map((key) => `${JSON.stringify(key)}:${canonicalJson(object[key])}`)
    .join(",")}}`;
}

function hashInput(input: Record<string, unknown>): string {
  return createHash("sha256").update(canonicalJson(input)).digest("base64url");
}

function signature(encodedPayload: string): Buffer {
  return createHmac("sha256", signingKey()).update(encodedPayload).digest();
}

function equalText(left: unknown, right: string): boolean {
  return typeof left === "string" && left === right;
}

export function issueAiConfirmationToken(
  identity: ConfirmationIdentity,
  nowMs = Date.now(),
): string {
  const payload: ConfirmationTokenPayload = {
    v: CONFIRMATION_TOKEN_VERSION,
    confirmationId: randomUUID(),
    userId: identity.userId,
    accountId: identity.accountId,
    toolUseId: identity.toolUseId,
    toolName: identity.toolName,
    inputHash: hashInput(identity.input),
    issuedAt: nowMs,
    expiresAt: nowMs + CONFIRMATION_TOKEN_TTL_MS,
  };
  const encodedPayload = Buffer.from(JSON.stringify(payload)).toString("base64url");
  return `${encodedPayload}.${signature(encodedPayload).toString("base64url")}`;
}

export function verifyAiConfirmationToken(
  token: string,
  identity: ConfirmationIdentity,
  nowMs = Date.now(),
): VerifiedConfirmation {
  try {
    const parts = token.split(".");
    if (parts.length !== 2) return { ok: false };

    const [encodedPayload, encodedSignature] = parts;
    const suppliedSignature = Buffer.from(encodedSignature, "base64url");
    const expectedSignature = signature(encodedPayload);
    if (
      suppliedSignature.length !== expectedSignature.length ||
      !timingSafeEqual(suppliedSignature, expectedSignature)
    ) {
      return { ok: false };
    }

    const payload = JSON.parse(
      Buffer.from(encodedPayload, "base64url").toString("utf8"),
    ) as Partial<ConfirmationTokenPayload>;

    if (
      payload.v !== CONFIRMATION_TOKEN_VERSION ||
      !equalText(payload.userId, identity.userId) ||
      !equalText(payload.accountId, identity.accountId) ||
      !equalText(payload.toolUseId, identity.toolUseId) ||
      !equalText(payload.toolName, identity.toolName) ||
      !equalText(payload.inputHash, hashInput(identity.input)) ||
      typeof payload.confirmationId !== "string" ||
      !/^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(
        payload.confirmationId,
      ) ||
      typeof payload.issuedAt !== "number" ||
      !Number.isFinite(payload.issuedAt) ||
      payload.issuedAt > nowMs + 60_000 ||
      typeof payload.expiresAt !== "number" ||
      !Number.isFinite(payload.expiresAt) ||
      payload.expiresAt <= nowMs
    ) {
      return { ok: false };
    }

    return { ok: true, confirmationId: payload.confirmationId };
  } catch {
    return { ok: false };
  }
}
