# Architecture Decisions

Record important architecture/product decisions here.

Do not rewrite history silently.

## 2026-08-17 — Monorepo tooling

npm workspaces (`apps/web`, `packages/*`) for the JS/TS side. Flutter
(`apps/mobile`) is not part of the npm workspace — it has its own
toolchain (pub) and is built/linted independently.

## 2026-08-17 — Unified account model

Every domain row (contacts, items, quotes, returns, listings, ...)
belongs to exactly one `account_id`. An account is either a person's
personal account or a business account — never both, never neither
(`accounts_owner_matches_type` check constraint). This is the single
shared ownership boundary CLAUDE.md asks for ("identity, account
context... shared" across MAKE/PROTECT/RECOVER): one authorization
function, `public.has_account_access(account_id)`, is reused by every
table's RLS policy instead of each domain reimplementing access control.
See `packages/domain-docs/README.md` for the full data model map.

A personal account is auto-created on profile creation; a business
account and an owner `business_members` row are auto-created on business
creation. Both via `AFTER INSERT` triggers, so client code never creates
accounts directly (`accounts` has no INSERT policy for `authenticated`).

## 2026-08-17 — Money is always integer cents

Every amount column is `*_cents bigint`. No floating point money,
anywhere, ever.

## 2026-08-17 — Ledger tables are append-only

`money_events` and `events` have SELECT + INSERT policies/grants only —
no UPDATE, no DELETE. Corrections are new rows, not edits, so the ledger
stays trustworthy as an audit trail. `valuations` follows the same
pattern (a history of estimates). `sales` allows UPDATE (to correct fees)
but not DELETE.

## 2026-08-17 — Local Supabase port range

This machine also runs MORT's local Supabase stack (Docker project id
`mort-mobile`, default ports 54321-54327). LOOP's `supabase/config.toml`
intentionally uses project_id `loop` and ports 55321-55329 so `supabase
start`/`db reset` can never collide with or touch MORT's containers. If
`supabase/config.toml` is ever regenerated (e.g. via `supabase init`),
these ports must be restored before running `supabase start` — see the
comment at the top of that file.

## 2026-08-17 — Where MAKE/PROTECT/RECOVER UI lives in the 5-tab nav

CLAUDE.md's five Primary Product Areas (Today, Money, Sell, Business,
AI) don't map 1:1 to the three engines, and ROADMAP.md's phases don't
say which tab hosts what. Decision, so this doesn't get re-litigated
per feature:

- **RECOVER** (valuations/listings/sales) lives under **Sell** — already
  built this way, it's the obvious fit (turning owned items into cash).
- **MAKE** (contacts/leads/opportunities/quotes) lives under
  **Business**, as `/business/contacts`, `/business/leads`, etc. —
  closing quotes is a business-development activity, and `contacts` as
  a shared core primitive (customers, vendors, buyers) belongs somewhere
  that isn't engine-specific. Business is that place.
- **PROTECT** (purchases/returns) lives under **Money**, as
  `/money/purchases` — a purchase is a spend event first and foremost,
  and returns/refunds are money events too. Warranties aren't built yet
  (would likely live on the same page). Today surfacing expiring
  windows as actions is still unbuilt — revisit once `actions` rows are
  generated from purchase/warranty deadlines, not just manually typed.
- `contacts` and `items` (shared core primitives, not MAKE/PROTECT/
  RECOVER-specific) will likely need their own top-level list views
  eventually, since PROTECT and RECOVER both reference `items` and
  MAKE references `contacts`. Not built yet — Contacts got a home under
  Business first because MAKE needed it first.

## 2026-08-17 — AI confirmation flow is two HTTP round trips, not the Tool Runner

`apps/web/src/app/api/ai/{chat,confirm}/route.ts` implement a manual
tool-use exchange rather than the Anthropic SDK's Tool Runner helper.
Reason: the Tool Runner auto-executes tool calls within a single
process call, but LOOP's Phase 8 requirement is a human confirmation
step *between* the model proposing an action and it actually running —
that pause has to survive a full page round trip (the user reads a
card, clicks Confirm, which is a separate request). So `/api/ai/chat`
returns a `tool_use` as a `tool_confirmation` payload without running
it; only `/api/ai/confirm`, called after the human clicks Confirm,
executes the tool and sends the `tool_result` back to Claude for a
follow-up turn. Model is always `claude-opus-5` unless a deployer sets
`ANTHROPIC_MODEL` — see `apps/web/src/lib/ai/client.ts`.

## 2026-08-17 — `@loop/contracts` is hand-maintained, not generated

`packages/contracts` mirrors `supabase/migrations` column-for-column as
zod schemas, by hand. Supabase's own TS type generator
(`generate_typescript_types`) requires a linked/running project; for now
the migrations are the single source of truth and contracts are kept in
sync manually. Revisit generating this once a real Supabase project
exists (see docs/KNOWN_ISSUES.md).
