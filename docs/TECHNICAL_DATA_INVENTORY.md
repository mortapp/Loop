# Technical Data Inventory

Updated: 2026-08-25

**TECHNICAL INPUT FOR PRIVACY/LEGAL REVIEW — NOT A PRIVACY POLICY.** This
document describes what LOOP's current schema and code actually store and
transmit, verified by reading `supabase/migrations/*.sql` and the
server/client code that writes to those tables. It draws no legal
conclusions and does not itself satisfy any disclosure requirement.

All rows below carry `account_id` and are governed by the same
`has_account_access()` RLS boundary (see `docs/SECURITY_DEFINER_INVENTORY.md`)
unless noted otherwise.

| Data type | Table(s) | Why collected | Retention | Who can read | Who can write | Third party? | Deletion path |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Email, display name, username | `profiles` | Account identity | Until account/profile deleted | Account members via RLS | Self (profile edit), server on signup | Supabase Auth (processor) | **None exists** — see below |
| Business name, membership/role | `businesses`, `business_members` | Multi-user business context | Until removed/deleted | Business members | Business admins, server on bootstrap | None | None exists |
| Account graph (which profiles belong to which accounts) | `accounts`, `business_members` | Multi-tenancy boundary | Until account deleted | Account members | Server-controlled (self-escalation blocked — `20260822173117_fix_business_members_self_escalation.sql`) | None | None exists |
| Contacts (name, email, phone, company, notes, tags) | `contacts` | CRM for Business area | Until deleted by user | Account members | Account members | None | Row-level delete available in UI; no bulk/account-wide deletion path |
| Items owned (name, description, category, condition, brand, model, serial number, purchase price/date) | `items` | OWN anchor entity for Sell/Protect | Until deleted | Account members | Account members | None | Row-level delete; item photos below |
| Item photos | Storage bucket `item-photos`, referenced by `items.photos` | User-uploaded product photos | Until removed | Account members via signed URL (private bucket, 1-hour TTL) | Account members, atomic attach/detach RPCs | None | `detach_item_photo` RPC + Storage `remove()`, already atomic (`20260823202606_make_item_photo_updates_atomic.sql`) |
| Valuations, listings, sales | `valuations`, `listings`, `sales` | RECOVER/ResellLens resale tracking | Valuations append-only (never mutated); listings/sales mutable within lifecycle | Account members | Account members via validated RPCs | None (no real marketplace API integration — Copy/Share/Export only, see `docs/KNOWN_ISSUES.md`) | No dedicated deletion path beyond normal row access |
| Purchases, returns, warranties, receipts/documents | `purchases`, `returns`, `warranties`, `documents` (+ private Storage) | PROTECT/ReturnGuard | Financial-adjacent records; no auto-expiry | Account members | Account members via validated RPCs/triggers | None | No dedicated deletion path |
| Money ledger | `money_events` | Core value ledger (MADE/PROTECTED/RECOVERED) | **Append-only, never updated or deleted** by design | Account members | Only via validated RPCs (never direct insert from client — `20260823060632_enforce_atomic_money_lifecycle.sql`) | None | By design, individual events are not deletable; only full-account erasure would remove them |
| Leads, opportunities, quotes, quote line items | `leads`, `opportunities`, `quotes`, `quote_line_items` | MAKE/QuoteCloser | Until deleted; quote status is forward-only once sent | Account members | Account members; quote creation/status locked to validated RPCs (`create_quote_with_line_items`, `set_quote_status_with_money_event`) | None | No dedicated deletion path for quotes beyond normal row access |
| Unified action queue | `actions` | Today engine | Until dismissed/deleted | Account members | Server (auto-generated) + account members | None | Row-level; auto-generated ones regenerate |
| Domain event log | `events` | Audit trail | **Append-only** | Account members | Server-controlled | None | Not deletable by design (audit log) |
| AI proposals/confirmations | Not a table — stateless. A signed (`ANTHROPIC_API_KEY`-HMAC) confirmation token carries the account/user/tool/input binding; only the *result* of a confirmed action lands in `actions`/`money_events`, gated by unique idempotency indexes (`20260823201710_make_ai_confirmations_idempotent.sql`) | Ask LOOP tool-call safety | Token is short-lived and never persisted; only the resulting mutation persists like any other | N/A (not stored) | N/A | **Anthropic**, only while `ANTHROPIC_API_KEY` is configured (currently unconfigured — no provider call happens today) | N/A |
| AI chat messages/conversation text | Not persisted server-side (grepped `apps/web/src/app/api/ai/`: no database insert in either route) | — | Not retained by LOOP's own database | — | — | **Anthropic** processes the request content while the key is configured; LOOP does not control Anthropic's own retention — check Anthropic's API data-retention terms before enabling in production | N/A |
| Auth credentials (password hash, session tokens) | Supabase's own `auth.*` schema, not `public.*` | Sign-in | Managed entirely by Supabase Auth | Supabase Auth internals only | Supabase Auth | **Supabase** (the auth processor itself) | Supabase Auth's own user-deletion API, not yet wired into any LOOP-side flow |

## What is NOT collected (verified by absence, not by policy claim)

- No advertising ID, no analytics/telemetry SDK, no push-notification
  token table, no location data, no camera/microphone access beyond the
  system photo picker's own permission model (image_picker's modern
  Android/iOS integration doesn't require a manifest permission on this
  project's target SDKs — see `docs/ANDROID_RELEASE_ARTIFACTS_RUNBOOK.md`).
- No third-party analytics or crash-reporting SDK found in
  `apps/mobile/pubspec.yaml` or `apps/web/package.json` dependencies.

## Account/data deletion — the real gap

**No account-deletion or bulk-data-deletion path exists anywhere in the
codebase** — verified by grepping mobile, web, and database source for
delete-account patterns; zero matches. A user can delete individual rows
they created (contacts, items, listings, etc. — where UI exists for it)
but there is no single action that removes a profile, its account
membership, and its Storage objects together, and no path to delete the
underlying Supabase Auth identity from within LOOP.

This matters for:

- Google OAuth consent screen requirements (see
  `docs/GOOGLE_OAUTH_RELEASE_CHECKLIST.md`).
- Google Play's Data Safety section, which asks whether users can request
  account/data deletion (see `docs/PLAY_DATA_SAFETY_TECHNICAL_INPUT.md`).
- Any future privacy policy's own deletion promise.

Building this is real, non-trivial engineering work with genuine product
and legal questions attached — most importantly, **what should happen to
`money_events` and `events` on deletion**, given they're deliberately
append-only/audit-log tables by design (do they get anonymized, retained
for a legal minimum, or actually deleted — that's a policy decision, not
an engineering one). This session did not build it, to avoid inventing
that policy unilaterally overnight. See
`docs/OWNER_RELEASE_ACTION_CENTER.md` for how to sequence this decision
and the resulting engineering work.

## Third-party processors currently in the runtime path

See `docs/THIRD_PARTY_DATA_FLOWS.md`.
