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

## `@loop/contracts` is hand-synced with migrations

See docs/DECISIONS.md — no automated drift check yet between
`supabase/migrations` and `packages/contracts/src`. A schema change that
forgets to update contracts will not be caught until a type error
surfaces downstream. Revisit once CI can run against a real/ephemeral
Supabase instance to generate types automatically.
