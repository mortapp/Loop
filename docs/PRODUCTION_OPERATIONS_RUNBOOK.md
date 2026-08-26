# Production Operations Runbook

Updated: 2026-08-25

Technical operations guidance for LOOP's current infrastructure: Vercel
(web), Supabase (`zqalnvfwxmfrnyjcuehq`, backend), Google (OAuth). This
does not promise 24/7 staffing or any specific response time — it's a
"what to actually do" reference for whoever is on point when something
breaks.

## Production web outage

1. Check Vercel's own status page and the project's Deployments tab for a
   failed/erroring deployment.
2. If the latest deployment is broken: use Vercel's **Instant Rollback**
   to the last known-good deployment (this session confirmed the most
   recent production deployment was `dpl_9GfiZdFYc5zvwQCFzKTag4LxwkfL`
   from commit `fc3f54d` — check `list_deployments` for the current
   latest-good one at incident time).
3. If Vercel itself is down, there's nothing to fix on LOOP's side —
   monitor Vercel's status page.

## Supabase outage

1. Check Supabase's status page.
2. If it's a LOOP-side issue (bad migration, RLS misconfiguration): see
   `docs/DATABASE_RELEASE_AND_RECOVERY_RUNBOOK.md`.
3. Mobile/web both fail closed on Supabase errors (see
   `docs/FAILURE_MODE_AUDIT.md`) — users see a retry-safe error state, not
   a crash, while Supabase is down.

## Google OAuth outage

1. Confirm via Google's own status dashboard whether it's Google-side.
2. Email/password sign-in remains available as a fallback — it's a
   separate code path from Google OAuth, not layered on top of it.

## AI (Ask LOOP) outage

1. If Anthropic itself is down: nothing to fix — the failure is already
   handled gracefully (see `docs/FAILURE_MODE_AUDIT.md`).
2. **To disable Ask LOOP immediately** (e.g. cost runaway, a discovered
   prompt-injection concern, or any reason to pull it fast): remove
   `ANTHROPIC_API_KEY` from Vercel's environment variables and redeploy.
   The routes already fail closed with a truthful message — no code
   change needed. See `docs/ASK_LOOP_PROVIDER_ENABLEMENT.md`.

## Bad migration

See the full procedure in `docs/DATABASE_RELEASE_AND_RECOVERY_RUNBOOK.md`.
Summary: never reset hosted, always write a new forward-only corrective
migration, capture evidence (advisor output, exact error, affected table
state) before making the corrective change.

## Storage incident (e.g. a photo becomes publicly accessible)

1. Item photos live in a **private** bucket served only via short-lived
   (1-hour) signed URLs — confirm the bucket's public/private flag hasn't
   been flipped in the Supabase dashboard (Storage → Buckets).
2. If a signed URL leaked (e.g. logged somewhere, shared accidentally),
   it self-expires within an hour; there's no way to revoke an
   already-issued signed URL early on Supabase Storage, so the exposure
   window is bounded by that TTL.
3. Check `get_advisors(type: security)` for any RLS/policy regression on
   `storage.objects`.

## Suspected cross-account exposure

1. Reproduce with two real (or synthetic-isolated) test accounts, not the
   owner's own data.
2. Check whether the exposure is at the RLS layer (a policy gap) or the
   application layer (a client rendering data it shouldn't have fetched,
   even if the fetch itself was correctly scoped) — these need different
   fixes.
3. If it's RLS: this is the single most serious class of bug LOOP can
   have. Write and test a corrective migration immediately (see the DB
   runbook), and treat it as the top priority regardless of what else is
   in flight.
4. Preserve logs/evidence of the exposure before remediating if at all
   possible, per the security incident checklist below.

## Credential leak (any kind)

See `docs/SECURITY_INCIDENT_CHECKLIST.md`.

## Bad deployment (web or mobile)

- **Web**: Vercel Instant Rollback (see "Production web outage" above).
- **Android**: Play Console supports halting a staged rollout or rolling
  back to a previous version on Play's side once a release exists — not
  applicable yet, since no production release has shipped.

## Freezing mutations (extreme/rare)

There is no built-in "read-only mode" flag in this codebase. If mutations
genuinely need to stop (e.g. a discovered financial-integrity bug), the
most direct lever is revoking the relevant `EXECUTE`/`INSERT`/`UPDATE`
grants on the affected table(s)/function(s) for the `authenticated` role
directly in Postgres, then restoring them once the fix is verified. This
is a blunt instrument — use it only when the alternative (leaving the bug
live) is worse, and restore access as soon as the corrective migration is
verified.

## Support escalation

No dedicated support tooling exists yet (no helpdesk integration, no
in-app support ticket system beyond the static Help screen). Until one
exists, escalation is whatever channel the owner already uses to hear
about problems.

## Evidence discipline

Across every scenario above: capture logs, advisor output, and exact
error text **before** taking a remediation action that would change the
state you're trying to diagnose. Never delete logs, revert a migration
file, or reset a database as a first response — those actions destroy the
evidence needed to understand what actually happened and to confirm the
fix worked.
