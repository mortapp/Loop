import { z } from "zod";

// Row schemas mirror `supabase/migrations/20260821234907_core_primitives.sql`
// column-for-column. Every table here carries `account_id` — the unified
// context shared by MAKE, PROTECT, and RECOVER.

export const contactSchema = z.object({
  id: z.string().uuid(),
  account_id: z.string().uuid(),
  display_name: z.string().min(1),
  email: z.string().email().nullable(),
  phone: z.string().nullable(),
  company: z.string().nullable(),
  notes: z.string().nullable(),
  tags: z.array(z.string()),
  created_by: z.string().uuid().nullable(),
  created_at: z.string(),
  updated_at: z.string(),
});
export type Contact = z.infer<typeof contactSchema>;

export const itemStatusSchema = z.enum(["owned", "returned", "listed", "sold", "disposed"]);
export type ItemStatus = z.infer<typeof itemStatusSchema>;

/** The OWN anchor entity that MAKE/PROTECT/RECOVER all hang off of. */
export const itemSchema = z.object({
  id: z.string().uuid(),
  account_id: z.string().uuid(),
  name: z.string().min(1),
  description: z.string().nullable(),
  category: z.string().nullable(),
  condition: z.string().nullable(),
  brand: z.string().nullable(),
  model: z.string().nullable(),
  serial_number: z.string().nullable(),
  purchase_price_cents: z.number().int().nullable(),
  purchase_date: z.string().nullable(),
  photos: z.array(z.string()),
  status: itemStatusSchema,
  created_by: z.string().uuid().nullable(),
  created_at: z.string(),
  updated_at: z.string(),
});
export type Item = z.infer<typeof itemSchema>;

/**
 * Statuses from which a listing may be created or a sale recorded — must
 * mirror `private.guard_listing_lifecycle`/`private.guard_sale_lifecycle` in
 * supabase/migrations/20260823060632_enforce_atomic_money_lifecycle.sql
 * (`v_item_status not in ('owned', 'listed')` is rejected). A returned or
 * disposed item is server-rejected even though it is not `sold`, so
 * `status !== "sold"` is not a valid eligibility check on its own.
 */
const SELLABLE_ITEM_STATUSES: ReadonlySet<ItemStatus> = new Set(["owned", "listed"]);

export function canPrepareListing(status: ItemStatus): boolean {
  return SELLABLE_ITEM_STATUSES.has(status);
}

export function canRecordSale(status: ItemStatus): boolean {
  return SELLABLE_ITEM_STATUSES.has(status);
}

export const documentKindSchema = z.enum([
  "receipt",
  "invoice",
  "quote",
  "warranty",
  "listing",
  "other",
]);
export type DocumentKind = z.infer<typeof documentKindSchema>;

export const documentSchema = z.object({
  id: z.string().uuid(),
  account_id: z.string().uuid(),
  item_id: z.string().uuid().nullable(),
  kind: documentKindSchema,
  related_type: z.string().nullable(),
  related_id: z.string().uuid().nullable(),
  storage_path: z.string().min(1),
  file_name: z.string().min(1),
  mime_type: z.string().nullable(),
  size_bytes: z.number().int().nullable(),
  created_by: z.string().uuid().nullable(),
  created_at: z.string(),
});
export type Document = z.infer<typeof documentSchema>;

export const moneyEventKindSchema = z.enum(["earn", "spend", "refund", "fee", "recovered"]);
export type MoneyEventKind = z.infer<typeof moneyEventKindSchema>;

/** Append-only ledger row. Never updated or deleted once inserted. */
export const moneyEventSchema = z.object({
  id: z.string().uuid(),
  account_id: z.string().uuid(),
  item_id: z.string().uuid().nullable(),
  kind: moneyEventKindSchema,
  amount_cents: z.number().int(),
  currency: z.string().length(3),
  occurred_at: z.string(),
  source_type: z.string().nullable(),
  source_id: z.string().uuid().nullable(),
  description: z.string().nullable(),
  created_by: z.string().uuid().nullable(),
  created_at: z.string(),
});
export type MoneyEvent = z.infer<typeof moneyEventSchema>;

export const actionStatusSchema = z.enum(["open", "snoozed", "done", "dismissed"]);
export type ActionStatus = z.infer<typeof actionStatusSchema>;

/** The unified queue that powers the Today engine. */
export const actionSchema = z.object({
  id: z.string().uuid(),
  account_id: z.string().uuid(),
  type: z.string().min(1),
  title: z.string().min(1),
  description: z.string().nullable(),
  status: actionStatusSchema,
  due_at: z.string().nullable(),
  related_type: z.string().nullable(),
  related_id: z.string().uuid().nullable(),
  assigned_to: z.string().uuid().nullable(),
  created_by: z.string().uuid().nullable(),
  created_at: z.string(),
  updated_at: z.string(),
  completed_at: z.string().nullable(),
});
export type Action = z.infer<typeof actionSchema>;

/** Append-only domain event. Never updated or deleted once inserted. */
export const eventSchema = z.object({
  id: z.string().uuid(),
  account_id: z.string().uuid(),
  type: z.string().min(1),
  payload: z.record(z.unknown()),
  related_type: z.string().nullable(),
  related_id: z.string().uuid().nullable(),
  actor_profile_id: z.string().uuid().nullable(),
  occurred_at: z.string(),
  created_at: z.string(),
});
export type Event = z.infer<typeof eventSchema>;
