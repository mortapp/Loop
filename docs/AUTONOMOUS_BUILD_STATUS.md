# LOOP Autonomous Build Status

## Current Phase

Phase 1 (Foundation) + Phase 2 (Identity) — schema and monorepo tooling
built and verified; apps (web/mobile) in progress.

## Completed

- Base repository structure created.
- Git initialized, GitHub remote configured (not yet pushed).
- Persistent Claude instructions created.
- Full Supabase schema designed and migrated locally (7 migrations):
  helpers, identity (profiles/businesses/business_members/accounts),
  core primitives (contacts/items/documents/money_events/actions/events),
  MAKE (leads/opportunities/quotes/quote_line_items), PROTECT
  (purchases/returns/warranties), RECOVER (valuations/listings/sales),
  storage (documents bucket + RLS).
- Local Supabase dev stack running (Docker, ports 55321-55329, isolated
  from MORT's stack on the same machine — see docs/DECISIONS.md).
- RLS verified end-to-end against a live local instance: identity
  auto-provisioning, cross-user isolation, business creation, append-only
  ledger inserts. Two real bugs found and fixed in the process (RLS
  self-recursion, missing GRANTs) — see docs/KNOWN_ISSUES.md.
- `@loop/contracts` package: zod schemas + types for every table, hand-
  mirrored from the migrations.
- `packages/domain-docs/README.md`: data model map from product concepts
  to schema.
- Root npm workspace tooling (`package.json`, `packages/shared-config`
  for shared tsconfig/eslint/prettier).
- Flutter mobile scaffold (`apps/mobile`) — in progress via background
  agent as of this writing; check back for completion before assuming
  done.

## In Progress

- Next.js web app scaffold (`apps/web`).
- Flutter mobile app scaffold (`apps/mobile`) — delegated to a background
  agent; verify its output (flutter analyze/format results) before
  trusting it's clean.

## Verified

- Migrations apply cleanly from empty on `supabase db reset`.
- Identity auto-provisioning (auth.users -> profiles -> personal
  account) works.
- Business creation auto-provisions owner membership + business account,
  including the `INSERT ... RETURNING` path.
- Cross-account RLS isolation confirmed for profiles, items, businesses.
- See docs/TEST_MATRIX.md for the full list.

## Failed

None outstanding — two issues were found and fixed during this pass
(documented in docs/KNOWN_ISSUES.md for future reference, not because
they're still broken).

## Blocked

- No hosted Supabase project exists yet (needs a human to pick an
  org/billing account and create it — see docs/KNOWN_ISSUES.md). Local
  development is unblocked in the meantime.
- CI cannot yet run database-dependent checks against a real project for
  the same reason.

## Remaining

- Flutter application (scaffold in progress)
- Next.js application (in progress)
- CI workflows (lint/build for web; analyze/format for mobile)
- Auth UI (sign up / sign in / account switcher) in both apps
- Today engine UI wired to `actions`/`events`
- MAKE / PROTECT / RECOVER feature UIs
- AI framework (tool registry, confirmation system, safe actions)
- Automated test suite (currently manual REST/psql smoke tests only)
- Documentation pass once apps exist

## Last Known Good Commit

Not yet established — first commit pending in this session.

## Next Action

Finish apps/web scaffold, review the Flutter agent's output, commit the
foundation, then continue toward Phase 3 (Today).

## Vercel Deployment Readiness (apps/web) — subagent note

Scoped subagent pass, 2026-08-17, covering deployment config only (not
feature work — that's owned by the parallel apps/web build). Summary:

- `npm ci` / `lint --workspace apps/web` / `typecheck --workspace
  apps/web` / `build --workspace apps/web` all pass against the current
  tree (added a `typecheck` script to `apps/web/package.json` — none
  shipped by `create-next-app`, and `.github/workflows/web-ci.yml`
  already expected one).
- No `apps/web/vercel.json` needed — Vercel's npm-workspaces monorepo
  auto-detection handles installing `@loop/contracts` from the repo
  root when Root Directory is set to `apps/web`.
- Added `NEXT_PUBLIC_SITE_URL` to root `.env.example` (already
  referenced by `apps/web/src/app/(auth)/actions.ts` and
  `apps/web/.env.local.example`, but missing from the root template).
- Full detail, human setup steps, and env var table: see
  `docs/VERCEL_DEPLOYMENT.md` (new).
- Did not touch anything under `apps/web/src` — inspected it read-only
  and found Supabase Auth (browser/server clients, PKCE callback,
  `proxy.ts` session refresh, sign-in/up) already substantially built,
  ahead of what this subagent expected going in.
