# LOOP Autonomous Build Status

## Current Phase

Phase 1 (Foundation) and Phase 2 (Identity) are built and verified.
Phase 3 (Today) is next — the schema exists (`actions`, `events`) but no
UI reads it yet.

## Completed

- Base repository structure, git initialized, GitHub remote configured
  (not yet pushed).
- Full Supabase schema, migrated and verified locally (7 migrations):
  helpers, identity (profiles/businesses/business_members/accounts),
  core primitives (contacts/items/documents/money_events/actions/
  events), MAKE (leads/opportunities/quotes/quote_line_items), PROTECT
  (purchases/returns/warranties), RECOVER (valuations/listings/sales),
  storage (documents bucket + RLS).
- Local Supabase dev stack running (Docker, ports 55321-55329, isolated
  from another local Supabase project on this machine — see
  docs/DECISIONS.md).
- RLS verified end-to-end, both manually (docs/TEST_MATRIX.md) and now
  as an automated pgTAP suite (`supabase/tests/database/`, 15/15
  passing). Two real bugs were found and fixed in the process (RLS
  self-recursion, missing GRANTs) — see docs/KNOWN_ISSUES.md.
- `@loop/contracts`: zod schemas + types for every table, hand-mirrored
  from the migrations. `packages/domain-docs/README.md`: data model map.
- Root npm workspace tooling (`package.json`, `packages/shared-config`).
- `apps/web`: Next.js 16 (App Router) client. Supabase Auth wired end to
  end — browser/server clients, `src/proxy.ts` (session refresh + route
  gating), PKCE `/auth/callback`, sign-in/sign-up. Authenticated shell
  for the five product areas (Today/Money/Sell/Business/AI); Business is
  wired to real data, the rest are placeholders. Lint/typecheck/build
  all pass; unauthenticated-route redirect behavior verified against a
  running dev server. Deployment readiness documented in
  docs/VERCEL_DEPLOYMENT.md (no Vercel project or hosted Supabase
  project exists yet — human steps only).
- `apps/mobile`: Flutter (Riverpod + GoRouter + supabase_flutter)
  mirroring the same five-tab shell and shared-core/domain-extension
  folder structure. Business tab has a working account-switcher UI.
  `flutter analyze` / `dart format` / `flutter test` all pass clean.
- CI workflows for all three (`web-ci.yml`, `mobile-ci.yml`,
  `supabase-ci.yml`) mirror the local verification steps above.

## Verified

See docs/TEST_MATRIX.md for the full, current list (Supabase/RLS pgTAP
suite, apps/web build + runtime redirect checks, apps/mobile
analyze/format/test).

## Failed

None outstanding — issues found during this build are documented in
docs/KNOWN_ISSUES.md as context for future work, not as open breakage.

## Blocked

- No hosted Supabase project exists yet (org/billing/region is a human
  decision). Local development is unblocked in the meantime.
- No Vercel project exists yet (GitHub repo isn't pushed, and creating/
  linking a Vercel project requires human account access). See
  docs/VERCEL_DEPLOYMENT.md "Human Action Required" for the full list.
- CI cannot run against a real hosted Supabase project for the same
  reason (local-stack-based `supabase-ci.yml` is unblocked).

## Remaining

- Today UI wired to `actions`/`events` (Phase 3).
- MAKE / PROTECT / RECOVER feature UIs beyond the Business tab
  (Phases 4-6).
- Cross-engine integration (Phase 7): purchase -> item, item -> return,
  item -> resale, quote -> revenue, sale -> recovered value — mostly a
  UI/workflow concern now that the schema already supports it.
- AI framework: tool registry, confirmation system, safe actions
  (Phase 8).
- Browser/component test coverage for apps/web (no JS/TS test runner
  configured yet — see docs/KNOWN_ISSUES.md).
- A real shared design system/token set between apps/web and
  apps/mobile — both currently have their own independently-chosen
  clean-but-different visual style (ROADMAP Phase 1 lists "Design
  system" and it isn't done yet).
- Push to GitHub, create hosted Supabase + Vercel projects (human
  steps).

## Last Known Good Commit

`9458b09` — "Add web and mobile app shells, CI workflows, and pgTAP
regression tests" (parent `7f4fccd`, the schema/tooling foundation).
Both commits are local only; not yet pushed to the `mortapp/Loop`
remote.

## Next Action

Build the Today feed (UI over `public.actions`/`public.events`) in both
apps, since Phase 3 is the next unbuilt roadmap phase and the schema for
it already exists.
