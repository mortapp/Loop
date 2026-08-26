# Security Incident Checklist

Updated: 2026-08-25

For any suspected security incident. Containment and evidence preservation
first, root-cause fix second — in that order, but never delete evidence in
service of containment (e.g. don't wipe logs to "clean up").

## Suspected token/credential leak (any of: Supabase service role, DB
password, Anthropic key, Google client secret, GitHub token, Vercel token)

1. **Rotate the specific credential immediately** at its source (Supabase
   dashboard for service-role/DB password, Google Cloud Console for the
   OAuth client secret, Anthropic console for the API key, GitHub for a
   PAT, Vercel for its own tokens). Rotation invalidates the leaked value
   regardless of where it leaked to.
2. Update the credential everywhere it's legitimately used (Vercel env
   vars, GitHub Actions secrets) immediately after rotating.
3. Check `git log -p` and GitHub's own secret-scanning alerts (if enabled)
   for how/when it entered the repository, if it did.
4. This session's own secret scan (`docs/CLAUDE_OVERNIGHT_RELEASE_READINESS.md`,
   Phase 5.1) found no tracked secrets as of `8d995aa` — if a leak is later
   discovered, treat it as a genuinely new finding, not something this
   audit missed by omission (re-run the same grep patterns to confirm).

## Suspected cross-account access (RLS bypass)

1. Reproduce against synthetic/isolated test accounts, not real user data.
2. Capture: the exact query/RPC call, the authenticated user's identity,
   the account it should have been scoped to, and the account whose data
   was exposed.
3. Run `get_advisors(type: security)` immediately — a new missing-RLS
   finding would surface here.
4. Fix via a forward-only migration (see
   `docs/DATABASE_RELEASE_AND_RECOVERY_RUNBOOK.md`), re-run the full
   209-case suite plus a targeted hostile-client test reproducing the
   exact exposure, and only then consider it closed.
5. If real user data was exposed (not just a synthetic reproduction),
   this crosses from "bug" into "incident requiring disclosure
   assessment" — a decision for the owner, informed by
   `docs/TECHNICAL_DATA_INVENTORY.md` (what data could have been exposed)
   and legal counsel, not something to self-resolve silently.

## Private Storage exposure

1. Confirm bucket privacy setting in Supabase dashboard hasn't changed.
2. Signed URLs self-expire in 1 hour (item photos) — note the exposure
   window is bounded by whatever TTL was in effect, and there is no way to
   revoke an already-issued signed URL early.
3. Check `get_advisors(type: security)` for a Storage-policy finding.

## Google OAuth credential exposure (client secret leaked)

1. Rotate the OAuth client secret in Google Cloud Console immediately.
2. Update it in the Supabase dashboard's Google provider config.
3. This does not require any LOOP code change — the client secret lives
   entirely in Supabase's provider configuration, never in this
   repository (verified this session — see `docs/GOOGLE_OAUTH_RELEASE_CHECKLIST.md`).

## Malicious or unexpected AI action

1. Immediately disable Ask LOOP: remove `ANTHROPIC_API_KEY` from Vercel
   and redeploy (see `docs/PRODUCTION_OPERATIONS_RUNBOOK.md`).
2. Every confirmed AI action is already bound to a specific
   account/user/tool/input via a signed, expiring confirmation token, and
   every resulting mutation is idempotent (`docs/SECURITY_DEFINER_INVENTORY.md`,
   `docs/FAILURE_MODE_AUDIT.md`) — so identify the exact `actions`/
   `money_events` row(s) via their `source_type = 'ai'` marker and inspect
   from there rather than guessing at scope.
3. Since AI conversation content isn't persisted server-side
   (`docs/TECHNICAL_DATA_INVENTORY.md`), the resulting database mutation is
   the only durable evidence on LOOP's side — capture it before any
   cleanup.

## Unexpected Money duplication

1. This would contradict every layer of tested protection (unique
   indexes, idempotent RPCs, the 209-case suite, and this session's
   physical re-verification of quote/sale/refund flows) — treat a real
   occurrence as high-severity and reproduce it exactly before touching
   anything.
2. Capture the exact `money_events` rows involved (`id`, `source_type`,
   `source_id`, `amount_cents`, `occurred_at`) before any corrective
   action — `money_events` is append-only by design, so the duplicate rows
   themselves are permanent evidence once written.
3. Identify which RPC/code path produced the duplicate, write a failing
   pgTAP test reproducing it, then fix and re-verify against that test
   before considering it closed.

## General containment principles

- Rotate before you investigate if a live credential is confirmed leaked
  — investigation time is exposure time.
- Reproduce before you fix — a fix for a misunderstood bug is often a new
  bug.
- Preserve logs and evidence before remediating state that would erase
  them.
- Never use `git reset --hard`, a hosted database reset, or a force-push
  as an incident response — none of those are reversible, and none of
  them are actually required by anything in this checklist.
