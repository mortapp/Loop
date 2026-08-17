import { z } from "zod";

// PROTECT / ReturnGuard. Row schemas mirror
// `supabase/migrations/20260817000005_protect.sql` column-for-column.

export const purchaseSchema = z.object({
  id: z.string().uuid(),
  account_id: z.string().uuid(),
  item_id: z.string().uuid().nullable(),
  vendor_contact_id: z.string().uuid().nullable(),
  vendor_name: z.string().nullable(),
  purchase_date: z.string().nullable(),
  price_cents: z.number().int().nullable(),
  receipt_document_id: z.string().uuid().nullable(),
  warranty_expires_at: z.string().nullable(),
  return_window_expires_at: z.string().nullable(),
  created_by: z.string().uuid().nullable(),
  created_at: z.string(),
  updated_at: z.string(),
});
export type Purchase = z.infer<typeof purchaseSchema>;

export const returnStatusSchema = z.enum([
  "initiated",
  "shipped",
  "received",
  "refunded",
  "denied",
]);
export type ReturnStatus = z.infer<typeof returnStatusSchema>;

export const returnSchema = z.object({
  id: z.string().uuid(),
  account_id: z.string().uuid(),
  item_id: z.string().uuid(),
  purchase_id: z.string().uuid().nullable(),
  reason: z.string().nullable(),
  status: returnStatusSchema,
  refund_amount_cents: z.number().int().nullable(),
  initiated_at: z.string(),
  resolved_at: z.string().nullable(),
  created_by: z.string().uuid().nullable(),
  created_at: z.string(),
  updated_at: z.string(),
});
export type Return = z.infer<typeof returnSchema>;

export const warrantySchema = z.object({
  id: z.string().uuid(),
  account_id: z.string().uuid(),
  item_id: z.string().uuid(),
  provider: z.string().nullable(),
  coverage_summary: z.string().nullable(),
  starts_at: z.string().nullable(),
  expires_at: z.string().nullable(),
  claim_status: z.string().nullable(),
  created_by: z.string().uuid().nullable(),
  created_at: z.string(),
  updated_at: z.string(),
});
export type Warranty = z.infer<typeof warrantySchema>;
