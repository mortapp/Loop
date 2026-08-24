export const MAX_MONEY_CENTS = 100_000_000_000;

type MoneyInputOptions = {
  allowZero?: boolean;
  maxCents?: number;
};

/** Converts ordinary decimal dollar text to cents without floating-point math. */
export function parseDollarsToCents(
  input: string,
  { allowZero = false, maxCents = MAX_MONEY_CENTS }: MoneyInputOptions = {},
): number | null {
  const value = input.trim();
  const match = /^(\d+)(?:\.(\d{1,2}))?$/.exec(value);
  if (!match || !Number.isSafeInteger(maxCents) || maxCents < 0) return null;

  const wholeDollars = Number(match[1]);
  if (!Number.isSafeInteger(wholeDollars)) return null;

  const fractionalCents = Number((match[2] ?? "").padEnd(2, "0") || "0");
  const cents = wholeDollars * 100 + fractionalCents;
  if (!Number.isSafeInteger(cents) || cents > maxCents || (!allowZero && cents === 0)) {
    return null;
  }

  return cents;
}

/** Applies the same exact-cents rules to untrusted JSON values such as AI tool input. */
export function parseDollarValueToCents(
  input: unknown,
  options?: MoneyInputOptions,
): number | null {
  if (typeof input === "number") {
    if (!Number.isFinite(input)) return null;
    return parseDollarsToCents(input.toString(), options);
  }
  if (typeof input === "string") return parseDollarsToCents(input, options);
  return null;
}

export function isUuid(value: string): boolean {
  return /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(value);
}
