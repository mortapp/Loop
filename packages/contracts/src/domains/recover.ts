import { z } from "zod";

// RECOVER / ResellLens. Row schemas mirror
// `supabase/migrations/20260817000006_recover.sql` column-for-column.

export const valuationSourceSchema = z.enum(["ai", "manual", "marketplace"]);
export type ValuationSource = z.infer<typeof valuationSourceSchema>;

/** A point-in-time estimate. Never mutated once inserted. */
export const valuationSchema = z.object({
  id: z.string().uuid(),
  account_id: z.string().uuid(),
  item_id: z.string().uuid(),
  source: valuationSourceSchema,
  estimated_value_cents: z.number().int(),
  confidence: z.number().nullable(),
  valued_at: z.string(),
  created_by: z.string().uuid().nullable(),
  created_at: z.string(),
});
export type Valuation = z.infer<typeof valuationSchema>;

export const listingStatusSchema = z.enum([
  "draft",
  "active",
  "sold",
  "removed",
]);
export type ListingStatus = z.infer<typeof listingStatusSchema>;

export const listingSchema = z.object({
  id: z.string().uuid(),
  account_id: z.string().uuid(),
  item_id: z.string().uuid(),
  marketplace: z.string().min(1),
  status: listingStatusSchema,
  list_price_cents: z.number().int().nullable(),
  listing_url: z.string().nullable(),
  published_at: z.string().nullable(),
  created_by: z.string().uuid().nullable(),
  created_at: z.string(),
  updated_at: z.string(),
});
export type Listing = z.infer<typeof listingSchema>;

export const saleSchema = z.object({
  id: z.string().uuid(),
  account_id: z.string().uuid(),
  item_id: z.string().uuid(),
  listing_id: z.string().uuid().nullable(),
  buyer_contact_id: z.string().uuid().nullable(),
  sale_price_cents: z.number().int(),
  fees_cents: z.number().int(),
  net_amount_cents: z.number().int(),
  sold_at: z.string(),
  created_by: z.string().uuid().nullable(),
  created_at: z.string(),
});
export type Sale = z.infer<typeof saleSchema>;
