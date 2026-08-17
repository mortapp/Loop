# LOOP Autonomous Build Status

## Current Phase

Phases 1-6 built and verified in `apps/web`, including real cross-engine
integration (Phase 7) between them. Phase 8 (AI) is still a placeholder.
`apps/mobile` has the shared shell but none of the MAKE/PROTECT/RECOVER
feature UIs web now has — mobile feature parity is the next big gap.

## Completed

- Full Supabase schema (7 migrations), verified locally and via an
  automated pgTAP suite (`supabase/tests/database/`, 15/15 passing).
- `@loop/contracts`, `packages/domain-docs`, root npm workspace tooling.
- `apps/mobile`: Flutter shell (Riverpod + GoRouter + supabase_flutter),
  five-tab nav, working account-switcher UI. Feature UIs (contacts,
  leads, quotes, items, purchases, money ledger) not yet built — web has
  all of these, mobile doesn't yet.
- `apps/web`: Next.js 16 (App Router), Supabase Auth wired end to end.
  Every one of the five product areas is functional, not a placeholder,
  except AI:
  - **Today**: unified `actions` queue — quick-add, done, dismiss,
    reopen.
  - **Money**: `money_events` ledger with per-kind totals + net, manual
    entry form, and **Purchases** (`/money/purchases`, PROTECT) —
    record a purchase (auto-logs a spend event), start a return, refund
    it (auto-logs a refund event, marks the item `returned`).
  - **Sell** (RECOVER): items, manual valuations, listings, and
    recording a sale (auto-logs a `recovered` money event, marks item +
    listing sold).
  - **Business** (MAKE, under `/business/*`): account switcher,
    contacts, leads (status cycling), opportunities (stage cycling),
    quotes (dynamic line items, computed totals, status cycling).
  - **AI**: still a placeholder — Phase 8, not started.
  - Cross-engine integration (Phase 7) is real, not aspirational: a
    RECOVER sale and a PROTECT refund both post directly to the same
    Money ledger, verified live end-to-end (see docs/TEST_MATRIX.md).
- CI workflows for all three (`web-ci.yml`, `mobile-ci.yml`,
  `supabase-ci.yml`).
- Pushed to `mortapp/Loop` (GitHub) via SSH; `main` is up to date with
  every commit below.

## Nav-placement decisions (see docs/DECISIONS.md for full reasoning)

CLAUDE.md's five tabs don't map 1:1 to the three engines:
- RECOVER → **Sell**
- MAKE → **Business** (`/business/contacts`, `/leads`, `/opportunities`,
  `/quotes`)
- PROTECT → **Money** (`/money/purchases`)

## Verified

Every feature above was checked three ways before being committed:
`lint` + `typecheck` + `next build` from the repo root, and the exact
Supabase query/mutation shapes each page uses exercised live via REST
against the running local instance (not just build-time type checks —
actual round trips against real RLS policies). Full detail in
docs/TEST_MATRIX.md. `apps/mobile`: `flutter analyze` / `dart format`
/ `flutter test` all clean.

## Failed

None outstanding.

## Blocked

- No hosted Supabase project or Vercel project yet (human account
  setup) — see docs/VERCEL_DEPLOYMENT.md "Human Action Required". Local
  development and GitHub are both unblocked.

## Remaining

- **Mobile feature parity**: apps/mobile has the shell but none of the
  Today/Money/Sell/Business feature UIs apps/web now has. Biggest gap.
- **AI (Phase 8)**: tool registry, confirmation system, safe actions —
  not started.
- **Warranties**: schema exists, no UI (Returns got built first as the
  more central ReturnGuard feature).
- **Today doesn't auto-populate yet**: actions are manually typed; nothing
  generates an action row from an expiring return window, an unsent
  quote, etc. The ledger integration (Phase 7) is real for money events,
  but action-generation automation isn't built.
- Quote creation is non-transactional (two sequential inserts) — see
  docs/KNOWN_ISSUES.md.
- No browser/component test runner for apps/web (manual + live REST
  verification only so far).
- A real shared design system between web and mobile (both are
  independently "clean" right now, not visually unified).
- Push to hosted Supabase / Vercel (human steps, see
  docs/VERCEL_DEPLOYMENT.md).

## Last Known Good Commit

`feaa93e` — "Add PROTECT: Purchases and Returns, completing Phase 5".
Pushed to `origin/main` (`mortapp/Loop`, SSH). Full history:

```
feaa93e  Add PROTECT: Purchases and Returns, completing Phase 5
97b8f90  Add Money ledger view, closing the loop with RECOVER
5eefd48  Add RECOVER: Sell page, completing Phase 6
018461d  Add MAKE: Opportunities and Quotes, completing Phase 4
ea767df  Add MAKE: Contacts and Leads under Business (Phase 4, part 1)
609d9a6  Add Today feed and account-switcher cookie (Phase 3)
5d73f44  Document runtime verification and update build status
9458b09  Add web and mobile app shells, CI workflows, pgTAP tests
7f4fccd  Foundation: unified account model, MAKE/PROTECT/RECOVER schema
```

## Next Action

Highest-leverage next chunk: bring `apps/mobile` up to feature parity
with what `apps/web` now has (Today, Money+Purchases, Sell, Business
contacts/leads/quotes), since that gap is now the widest one in the
build. AI (Phase 8) is the other major unstarted area.
