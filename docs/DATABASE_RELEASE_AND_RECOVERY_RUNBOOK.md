# Database Release and Recovery Runbook

Updated: 2026-08-25

Hosted project: `zqalnvfwxmfrnyjcuehq` (Postgres 17.6, `us-west-2`, Free
plan). Local isolated stack: ports 55321-55329, `project_id = "loop"` in
`supabase/config.toml` — never shares containers with MORT's local stack.

## Checking migration parity

Local migration files are the source of truth in git. To confirm the
hosted project matches:

```
ls supabase/migrations/*.sql   # count and names
```

Compare against the hosted list (via the Supabase dashboard's Database →
Migrations page, or the `list_migrations` MCP tool if available). They
must match filename-for-filename. As of `8e4abcf` this is an exact 27/27
match — verified this session.

## Applying a new migration (forward-only)

1. Write the migration in `supabase/migrations/<timestamp>_<name>.sql`
   using `supabase migration new <name>` so the timestamp ordering is
   correct.
2. Test locally first:
   ```
   npx supabase db reset --local
   npx supabase test db --local
   ```
   Both must pass before the migration ever touches the hosted project.
   `db reset --local` only ever touches the local Docker Postgres
   container on LOOP's isolated ports — it is not reachable from the
   hosted project and cannot affect it.
3. Apply to hosted with `supabase db push` (or the dashboard's SQL editor
   for a one-off, if that's the team's process) — never `db reset` against
   the hosted project; there is no "hosted reset" in this runbook's
   vocabulary because it would destroy real user data.
4. Re-run migration parity check immediately after.

## Detecting a failed/partial migration

- A `supabase db push` that errors mid-migration leaves the hosted
  `supabase_migrations.schema_migrations` table without a row for that
  migration — check it directly if unsure.
- Run `get_advisors(type: security)` and `get_advisors(type: performance)`
  immediately after any schema change; a new RLS-missing or
  privilege-escalation finding here is a stop-the-line signal.
- Spot-check RLS on any newly-touched table: as an authenticated non-owner
  test user, attempt a read/write on another account's row and confirm
  denial (the pattern used throughout `supabase/tests/database/`).
- Spot-check that any RPC the migration touched is still callable with the
  expected grants: `select proname, proacl from pg_proc where proname =
  '<name>';` or simply call it from an authenticated test session.

## Stopping deployment after a schema failure

There is no automatic hosted rollback in this project's tooling. If a
migration partially applied and broke something:

1. **Do not** attempt `supabase db reset` against hosted — it would drop
   and recreate the entire hosted database from the migration history,
   destroying all real data.
2. Write a new, forward-only corrective migration that undoes or repairs
   the specific broken change (e.g. `drop trigger ... ; create trigger
   ...` with the fixed body). Test it locally exactly as in "Applying a
   new migration" above before pushing.
3. If a table was left in an inconsistent state (e.g. a partially-applied
   `alter table`), capture the exact current schema
   (`\d+ <table>` in `psql`, or the dashboard's table editor) as evidence
   before writing the corrective migration, so the fix is based on actual
   state, not assumption.
4. Never rewrite or delete an already-applied migration file — always add
   a new one, even to fix a mistake in a very recent migration, once it
   has touched the hosted project.

## Capturing evidence before any recovery action

- Screenshot or copy the exact error message from `supabase db push` or
  the dashboard.
- Run `get_advisors` for both types and save the output.
- Note the exact timestamp and the migration filename involved.
- Do this before making any corrective change — a corrective migration
  changes the state you'd otherwise want to inspect.

## Backup / restore reality (Free plan)

Verified tonight via `get_organization`: the LOOP Supabase project
(`zqalnvfwxmfrnyjcuehq`) is on the **Free** plan.

- `KNOWN_BACKUP_CAPABILITY=` **not independently verified against Supabase's
  current published policy tonight** — Supabase's exact Free-plan backup
  retention and point-in-time-recovery (PITR) availability have changed
  over time across plan tiers, and asserting a specific retention window
  here without checking the live dashboard would be exactly the kind of
  unverified backup guarantee this phase exists to avoid.
- `OWNER_ACTION_REQUIRED=` before relying on this in an incident: open the
  hosted project's **Database → Backups** page in the Supabase dashboard
  and record what's actually offered today (daily backups, retention
  window, whether PITR is available on Free or requires an upgrade).
- `POINT_IN_TIME_RECOVERY=` typically a paid-plan feature on Supabase, but
  confirm current state in the dashboard rather than trusting this
  document's memory of past pricing pages.
- `FREE_PLAN_LIMITATION=` in general, Supabase Free-plan projects have
  materially weaker backup guarantees than paid plans, and Free projects
  can be paused after a period of inactivity — check the dashboard's
  project settings for the current inactivity-pause policy too, since a
  paused project needs to be manually restored before it serves traffic
  again.
- `RECOMMENDED_PRE_RELEASE_ACTION=` before any production launch that real
  users will trust with financial-ledger data (which is exactly what
  LOOP's Money/Protect data is), take a manual export
  (`pg_dump` via the connection string, or the dashboard's backup/export
  tooling) and store it somewhere outside Supabase at least once, so a
  worst-case project-level incident isn't a total-loss event. This is
  independent of whatever plan tier is chosen.

This document does not authorize a plan upgrade — that's a payment
decision for the owner (see `docs/OWNER_RELEASE_ACTION_CENTER.md`).

## What this runbook deliberately does not include

A destructive rollback mechanism for applied migrations. Postgres schema
changes are not reliably reversible in general (a dropped column's data is
gone), so the only safe recovery model here is forward-only correction,
matching how this project has always shipped fixes — see
`docs/KNOWN_ISSUES.md`'s "Resolved in the Final Pass" section for examples
of real forward-only fixes already shipped this way.
