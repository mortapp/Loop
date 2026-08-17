import { z } from "zod";

// Row schemas mirror `supabase/migrations/20260817000002_identity.sql`
// column-for-column (snake_case, matching what the Supabase client returns).

export const accountModeSchema = z.enum(["personal", "business", "both"]);
export type AccountMode = z.infer<typeof accountModeSchema>;

export const profileSchema = z.object({
  id: z.string().uuid(),
  email: z.string().email(),
  display_name: z.string().nullable(),
  avatar_url: z.string().nullable(),
  default_mode: accountModeSchema,
  created_at: z.string(),
  updated_at: z.string(),
});
export type Profile = z.infer<typeof profileSchema>;

export const memberRoleSchema = z.enum(["owner", "admin", "member"]);
export type MemberRole = z.infer<typeof memberRoleSchema>;

export const memberStatusSchema = z.enum(["invited", "active", "removed"]);
export type MemberStatus = z.infer<typeof memberStatusSchema>;

export const businessSchema = z.object({
  id: z.string().uuid(),
  name: z.string().min(1),
  slug: z.string().min(1),
  created_by: z.string().uuid(),
  created_at: z.string(),
  updated_at: z.string(),
});
export type Business = z.infer<typeof businessSchema>;

export const businessMemberSchema = z.object({
  id: z.string().uuid(),
  business_id: z.string().uuid(),
  profile_id: z.string().uuid(),
  role: memberRoleSchema,
  status: memberStatusSchema,
  invited_by: z.string().uuid().nullable(),
  created_at: z.string(),
  updated_at: z.string(),
});
export type BusinessMember = z.infer<typeof businessMemberSchema>;

export const accountTypeSchema = z.enum(["personal", "business"]);
export type AccountType = z.infer<typeof accountTypeSchema>;

/**
 * The unified acting context every domain row hangs off of via
 * `account_id`. Exactly one of `owner_profile_id` / `business_id` is set,
 * matching the `type` discriminant — mirrored here as a discriminated
 * union so callers get that guarantee at the type level too.
 */
export const accountSchema = z.discriminatedUnion("type", [
  z.object({
    id: z.string().uuid(),
    type: z.literal("personal"),
    owner_profile_id: z.string().uuid(),
    business_id: z.null(),
    created_at: z.string(),
  }),
  z.object({
    id: z.string().uuid(),
    type: z.literal("business"),
    owner_profile_id: z.null(),
    business_id: z.string().uuid(),
    created_at: z.string(),
  }),
]);
export type Account = z.infer<typeof accountSchema>;
