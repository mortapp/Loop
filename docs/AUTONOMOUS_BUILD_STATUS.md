# LOOP Autonomous Build Status

## Current Phase

Phases 1-8 all have real, verified implementations in both `apps/web`
and `apps/mobile`. Phase 8 (AI) is functionally complete but has never
made a live model call — no `ANTHROPIC_API_KEY` exists in this
environment (human step). Remaining work is depth (warranties on
mobile, streaming AI responses, more AI tools) and polish (a real
shared design system, browser/component test coverage), not missing
surface area.

## Completed

- Full Supabase schema (8 migrations) verified locally and via an
  automated pgTAP suite (`supabase/tests/database/`, 20/20 passing
  across 2 files).
- `@loop/contracts`, `packages/domain-docs`, root npm workspace tooling.
- **apps/web** (Next.js 16): every one of the five product areas is
  real, not a placeholder —
  - Today: `actions` queue, quick-add/done/dismiss/reopen.
  - Money: `money_events` ledger + totals + manual entry; Purchases
    (`/money/purchases`, PROTECT): purchases, returns, **and
    warranties**.
  - Sell (RECOVER): items, valuations, listings, sales.
  - Business (MAKE, under `/business/*`): contacts, leads,
    opportunities, quotes (line items via an atomic Postgres RPC —
    `create_quote_with_line_items`).
  - AI (Phase 8): tool registry (`create_action`, `log_money_event`)
    with a mandatory human confirm/decline step before any tool
    executes — `/api/ai/chat` + `/api/ai/confirm`. Built and verified
    to compile/build; **never exercised against a real model** (no API
    key — see docs/KNOWN_ISSUES.md).
  - Cross-engine integration (Phase 7) is real: RECOVER sales, PROTECT
    refunds, and MAKE (implicitly, once quotes convert) all post to the
    same Money ledger, verified live end-to-end.
- **apps/mobile** (Flutter): feature parity with web for Today, Money
  (+ Purchases/Returns, not yet Warranties), Sell, and Business/MAKE
  (contacts/leads/opportunities/quotes). Same account-switcher, same
  five-tab shell. Quote creation is not yet on the transactional RPC
  web uses — see docs/KNOWN_ISSUES.md.
- CI workflows for all three (`web-ci.yml`, `mobile-ci.yml`,
  `supabase-ci.yml`).
- Pushed to `mortapp/Loop` (GitHub) via SSH; `origin/main` is fully
  up to date as of this writing.

## Nav-placement decisions (see docs/DECISIONS.md for full reasoning)

RECOVER → **Sell**. MAKE → **Business** (`/business/contacts`,
`/leads`, `/opportunities`, `/quotes`). PROTECT → **Money**
(`/money/purchases`, now including warranties).

## Verified

Every web feature: `lint` + `typecheck` + `next build` from the repo
root, plus the exact Supabase query/mutation shapes exercised live via
REST against the running local instance. Every mobile feature:
independently re-run `dart format` / `flutter analyze` / `flutter
test` (not just trusting the building agent's self-report) — all
clean. AI: build-verified only, not live-verified (no credential).
Full detail in docs/TEST_MATRIX.md.

## Failed

None outstanding.

## Blocked

- **`ANTHROPIC_API_KEY`**: AI chat cannot be exercised end-to-end
  without one. Set it (and optionally `ANTHROPIC_MODEL`, defaults to
  `claude-opus-5`) in `apps/web/.env.local` — see `.env.example`. This
  is the only thing standing between the current AI code and a real
  conversation. Genuinely still blocked — no key exists anywhere in
  this environment, and one was not fabricated.

## Deployed (2026-08-21)

Both the hosted Supabase project and the Vercel project already
existed (created 2026-08-17, same day as the original build) but
neither had ever been finished — this was found and fixed live, not
assumed from docs:

- **Supabase** (`zqalnvfwxmfrnyjcuehq`, org "Loop", us-west-2): had
  zero migrations and zero tables despite being `ACTIVE_HEALTHY`. All
  8 schema migrations applied in order; confirmed via `list_tables`
  that all 20 land with RLS enabled. A fresh security-advisor scan
  (only possible against a real hosted project, not local Postgres)
  found two real gaps neither migration author nor local pgTAP had
  caught: two functions without a pinned `search_path`, and every
  `SECURITY DEFINER` function still executable by `anon` because
  Postgres grants EXECUTE to PUBLIC by default and nothing had
  explicitly revoked it. Fixed in
  `20260821235200_harden_function_search_path_and_grants.sql`,
  applied to the hosted project and committed so local dev picks it
  up too. Reverified clean afterward. `apps/web/.env.local` now
  points at this hosted project instead of local Docker (which isn't
  running in this environment) — `lint`/`typecheck`/`build` reverified
  clean against it.
- **Vercel** (`loop`, team `mortapphelp-7067s-projects`, linked to
  `mortapp/Loop`): **every one of its 13 prior deployment attempts had
  errored** — `list_deployments` showed 100% failure back to the very
  first commit. Root cause found from the build log, not guessed:
  Root Directory was never set to `apps/web` and Framework Preset was
  stuck on "Other", so Vercel built successfully but then looked for
  a static `public/` output directory at the repo root and failed with
  "No Output Directory named public found". Fixed both settings
  (Root Directory → `apps/web`, Framework Preset → Next.js) and the
  three `NEXT_PUBLIC_*` env vars (previously unset entirely) via the
  dashboard, then redeployed. **First successful production
  deployment in the project's history**: `READY`, correctly built as
  real Next.js serverless functions (not a static misfire), live at
  https://loop-teal-rho.vercel.app — fetched directly and confirmed it
  renders the real sign-in UI with the correct tagline, zero runtime
  errors in the last hour. Env vars now cover both Production and
  Preview scopes so future PR/branch deployments will build too, not
  just `main`.

## Remaining

- **AI depth**: only two tools exist (`create_action`,
  `log_money_event`); no streaming (responses are non-streaming
  request/response, a deliberate v1 scope cut — see
  docs/KNOWN_ISSUES.md rationale in this doc's history); no AI surface
  on mobile at all yet.
- **Mobile**: Warranties not built (web has it, mobile doesn't); quote
  creation not yet migrated to the transactional RPC.
- **Today doesn't auto-populate**: actions are manually typed; nothing
  yet generates an action row from an expiring return window, an
  unsent quote, etc.
- No browser/component test runner for apps/web (manual + live REST
  verification only).
- A real shared design system between web and mobile (both are
  independently "clean" right now, not visually unified).
- ~~Push local commits to `origin/main`; push to hosted Supabase /
  Vercel~~ — done; see "Deployed" above.

## Last Known Good Commit

`1ed147a` — "Add AI: tool registry with confirmation gating, starting
Phase 8". Pushed; `origin/main` matches local `main`. Full history
(newest first):

```
1ed147a  Add AI: tool registry with confirmation gating, starting Phase 8
90c7fae  Bring mobile to feature parity with web (Today, Money+Purchases, Sell, MAKE)
665cf8c  Add Warranties, completing PROTECT
1fd5259  Make quote creation transactional via a Postgres RPC
ac78d42  Update build status: Phases 1-6 + cross-engine integration complete in web
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

Mobile Warranties (closes the mobile/web gap), or AI tool-registry
depth (more safe actions, streaming), or the shared design system —
all reasonable next chunks, none blocking.
