import { z } from "zod";

// MAKE / QuoteCloser. Row schemas mirror
// `supabase/migrations/20260821234924_make.sql` column-for-column.

export const leadStatusSchema = z.enum([
  "new",
  "contacted",
  "qualified",
  "disqualified",
  "converted",
]);
export type LeadStatus = z.infer<typeof leadStatusSchema>;

export const leadSchema = z.object({
  id: z.string().uuid(),
  account_id: z.string().uuid(),
  contact_id: z.string().uuid().nullable(),
  source: z.string().nullable(),
  status: leadStatusSchema,
  notes: z.string().nullable(),
  created_by: z.string().uuid().nullable(),
  created_at: z.string(),
  updated_at: z.string(),
});
export type Lead = z.infer<typeof leadSchema>;

export const opportunityStageSchema = z.enum([
  "new",
  "qualifying",
  "quoted",
  "negotiating",
  "won",
  "lost",
]);
export type OpportunityStage = z.infer<typeof opportunityStageSchema>;

export const opportunitySchema = z.object({
  id: z.string().uuid(),
  account_id: z.string().uuid(),
  contact_id: z.string().uuid().nullable(),
  lead_id: z.string().uuid().nullable(),
  title: z.string().min(1),
  stage: opportunityStageSchema,
  estimated_value_cents: z.number().int().nullable(),
  created_by: z.string().uuid().nullable(),
  created_at: z.string(),
  updated_at: z.string(),
});
export type Opportunity = z.infer<typeof opportunitySchema>;

export const quoteStatusSchema = z.enum([
  "draft",
  "sent",
  "viewed",
  "accepted",
  "declined",
  "expired",
]);
export type QuoteStatus = z.infer<typeof quoteStatusSchema>;

export const quoteSchema = z.object({
  id: z.string().uuid(),
  account_id: z.string().uuid(),
  opportunity_id: z.string().uuid().nullable(),
  contact_id: z.string().uuid().nullable(),
  quote_number: z.string().min(1),
  status: quoteStatusSchema,
  subtotal_cents: z.number().int(),
  tax_cents: z.number().int(),
  total_cents: z.number().int(),
  currency: z.string().length(3),
  valid_until: z.string().nullable(),
  sent_at: z.string().nullable(),
  accepted_at: z.string().nullable(),
  created_by: z.string().uuid().nullable(),
  created_at: z.string(),
  updated_at: z.string(),
});
export type Quote = z.infer<typeof quoteSchema>;

export const quoteLineItemSchema = z.object({
  id: z.string().uuid(),
  quote_id: z.string().uuid(),
  description: z.string().min(1),
  quantity: z.number(),
  unit_price_cents: z.number().int(),
  position: z.number().int(),
});
export type QuoteLineItem = z.infer<typeof quoteLineItemSchema>;
