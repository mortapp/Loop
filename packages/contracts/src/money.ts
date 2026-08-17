import { z } from "zod";

/**
 * LOOP stores every money amount as integer cents to avoid floating point
 * drift. `Money` is the shared shape used across quotes, purchases,
 * returns, and sales.
 */
export const moneySchema = z.object({
  amountCents: z.number().int(),
  currency: z.string().length(3).default("USD"),
});
export type Money = z.infer<typeof moneySchema>;

export const currencySchema = z.string().length(3);
