# Known Issues

## No hosted Supabase project yet

There is no cloud Supabase project for LOOP — only the local Docker stack
(`supabase/config.toml`, project id `loop`). `.env.example` has empty
values. Creating a hosted project is a human decision (org/billing
account, project name/region) — blocked pending that choice. Local
development is fully functional in the meantime (`supabase start`).

## Supabase CLI 2.108.0 does not auto-expose new tables

The installed CLI's default config (`auto_expose_new_tables` unset)
matches the new secure-by-default cloud behavior: newly created tables
are **not** reachable by `anon`/`authenticated`/`service_role` without an
explicit `GRANT`. RLS policies alone are not enough — a table with a
correct RLS policy but no GRANT returns `42501 permission denied`, not an
empty result set. Every migration that creates a table for
user-facing access must include `grant select/insert/update/delete on
public.<table> to authenticated;` alongside its policies (see the end of
each migration file in `supabase/migrations/` for the pattern).

## RLS self-reference recursion

A policy on table T cannot query T directly from within its own USING/
WITH CHECK clause — Postgres raises `infinite recursion detected in
policy`. This bit `business_members`' own policies (checking membership
of the very table being queried) and `profiles`' peer-visibility policy
(joining `business_members` twice). Fixed by routing the membership
check through `SECURITY DEFINER` helper functions
(`is_active_business_member`, `is_business_admin`,
`shares_active_business` in `20260817000002_identity.sql`), which bypass
RLS internally and break the cycle. Any future policy that needs to
check membership/role should call these helpers rather than inlining a
fresh subquery on `business_members`.

## `INSERT ... RETURNING` re-checks the SELECT policy

When a client asks for the row back on insert (e.g. Supabase JS
`.insert().select()`, or PostgREST's `Prefer: return=representation`),
Postgres re-checks the table's SELECT policy against the new row —
and does so before any `AFTER INSERT` trigger on that same table has run.
This broke business creation: `businesses_select_members` originally
only allowed rows visible via `business_members`, but that row is
created by an `AFTER INSERT` trigger on `businesses` itself, which
hadn't fired yet when the RETURNING check happened. Fixed by adding
`created_by = auth.uid()` to `businesses_select_members` so the creator
can always see what they just created. Keep this in mind for any future
table where a trigger provisions the very access that table's own SELECT
policy depends on.

## No browser/component test coverage for apps/web yet

Only build-time checks (lint, typecheck, `next build`) and a few
unauthenticated-route curl checks have been run against `apps/web` (see
docs/TEST_MATRIX.md). The actual sign-up → sign-in → authenticated-app
click-through has not been exercised in a real browser. No JS/TS test
runner is configured. Add one (and Playwright or similar for the auth
flow) before treating apps/web as more than a verified-to-compile
scaffold.

## `npm install` can silently corrupt packages inside a OneDrive-synced repo

Observed on this machine: `npm install`/`npm ci` running inside a
OneDrive-synced folder can intermittently drop files during tarball
extraction (`npm warn tar TAR_ENTRY_ERROR ENOENT`), most often losing a
package's `.d.ts` files without any install-time error — `tsc` then
fails with a misleading "Could not find a declaration file" error that
looks like an application bug. If that happens, `rm -rf
node_modules/<package>` and reinstall just that package rather than
debugging application code. Doesn't affect Vercel's Linux build
environment — see docs/VERCEL_DEPLOYMENT.md.

## ~~Quote creation is not transactional~~ — fixed 2026-08-17

Was: `createQuote` inserted the `quotes` header row, then
`quote_line_items` in a second request, so a failure between the two
left an orphaned header. Fixed by `public.create_quote_with_line_items`
(`supabase/migrations/20260817000008_quote_rpc.sql`), a `security
invoker` plpgsql function that does both inserts in one transaction;
`createQuote` now calls it via `.rpc()`. Verified live: a successful
call returns the quote id with its line items attached, and a rejected
call (empty line items) leaves no quote row at all. Note for future
`jsonb_array_elements(...) WITH ORDINALITY` uses: you must alias both
output columns explicitly (`AS t(item, line_ordinality)`) — omitting
the alias list binds `item` to the whole `(value, ordinality)` record
instead of just the jsonb value, breaking `->>`/`->` with `operator
does not exist: record ->> unknown`.

## AI (Phase 8) is built but blocked on a credential

`ANTHROPIC_API_KEY` is unset — there is no Anthropic API key configured
anywhere in this environment. `apps/web`'s AI chat (tool registry:
`create_action`, `log_money_event`, both gated behind an explicit
confirm/decline step before executing) is fully implemented and passes
lint/typecheck/build, but has never made a real model call — it cannot
be live-verified the way every other feature in this build was. The
`/ai` page detects the missing key and shows a "not configured" state
rather than a broken chat UI. Setting the key (and optionally
`ANTHROPIC_MODEL`, see `.env.example`) is a human step — see
docs/AUTONOMOUS_BUILD_STATUS.md "Blocked".

## Mobile's quote creation drifted from web's (both non-transactional... differently)

Web's quote creation (`apps/web/.../business/quotes/actions.ts`) now
calls `public.create_quote_with_line_items` — see the resolved "Quote
creation is not transactional" entry above. Mobile's equivalent
(`apps/mobile/lib/features/business/quotes/quotes_providers.dart`) was
built by a separate agent pass that read the *pre-RPC* web code and
correctly mirrored what was there at the time: a two-step insert. The
two platforms are now inconsistent — mobile still has the header/
line-items race the RPC was written to fix. Low urgency (same low
volume risk as before), but worth swapping mobile's `createQuote` to
call the same RPC via `_client.rpc('create_quote_with_line_items', {...})`
next time that file is touched.

## `@loop/contracts` is hand-synced with migrations

See docs/DECISIONS.md — no automated drift check yet between
`supabase/migrations` and `packages/contracts/src`. A schema change that
forgets to update contracts will not be caught until a type error
surfaces downstream. Revisit once CI can run against a real/ephemeral
Supabase instance to generate types automatically.
