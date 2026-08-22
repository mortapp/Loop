# LOOP Continuation Prompt

Use this to resume LOOP work in a fresh session with no memory of prior
conversations. The repository is the source of truth — verify
everything below live rather than trusting this file if it's more than
a few days old.

## Recovery steps (do this first, every time)

```
cd "C:\Users\micha\OneDrive\Desktop\Loop"
git status
git log --oneline --decorate -10
git remote -v
```

Expect: clean tree, `main` up to date with `origin/main`
(`git@github.com:mortapp/Loop.git`). If not, stop and figure out why
before touching anything — do not assume, do not force-push.

Read, in order: `docs/AUTONOMOUS_BUILD_STATUS.md` (what's built),
`docs/KNOWN_ISSUES.md` (known gotchas and their fixes),
`docs/LOOP_COMPLETION_LEDGER.md` (row-by-row status),
`CLAUDE.md` (project rules — never modify MORT, never use MORT's
Supabase project, never disable RLS).

## Live infrastructure (verify, don't assume)

- **Supabase**: hosted project `zqalnvfwxmfrnyjcuehq`, org "Loop"
  (`mzkhysoovbzhkkgeqtku`), region us-west-2. Check via Supabase MCP
  `list_migrations`/`list_tables`/`get_advisors` before assuming
  schema state — this project was found completely unmigrated on
  2026-08-21 despite existing since 2026-08-17, so "the project
  exists" is not the same as "it's set up."
- **Vercel**: project `loop` (`prj_zgoDaWhw4m7uBj8PjgfalFKXbmFV`),
  team `mortapphelp-7067s-projects`. Production:
  https://loop-teal-rho.vercel.app — live since 2026-08-21. If a
  future deployment errors, check `get_deployment_build_logs` first;
  the entire deployment history before 2026-08-21 failed because Root
  Directory and Framework Preset were never set (Settings → Build and
  Deployment) — verify those haven't drifted back before assuming a
  code bug.
- **`apps/web/.env.local`**: gitignored, currently points at the
  hosted Supabase project (not local Docker, since Docker Desktop
  isn't running in this environment). If working somewhere Docker
  *is* available, `supabase start` + copying `supabase status -o env`
  values is the documented local-dev path — either is fine, just know
  which one is live before debugging a "why is my data missing" issue.

## What's genuinely done vs. not (see LOOP_COMPLETION_LEDGER.md for the full table)

Done: schema + RLS + storage on the real hosted project, both apps'
core five areas (Today/Money/Sell/Business/AI-scaffold) real and
functional, CI actually runs the real test suites now, first-ever
successful production deployment (verified live), Google Sign-In live
end-to-end on web, a real shared design system (docs/DESIGN_SYSTEM.md
— "Ledger" direction, identical tokens on web + mobile, WCAG-verified)
applied to web's 5 representative screens + shell and to mobile's
Today/Money/Sell/Purchases/Quotes screens.

Not done, no owner action needed — just pick one and go:
1. Mobile Warranties (closes the last web/mobile PROTECT gap).
2. Mobile quote creation → swap to `create_quote_with_line_items` RPC
   (mobile still has the two-step race web used to have).
3. AI mobile surface, or more AI tools, or streaming (all reasonable
   Phase 8 depth work).
4. Today auto-population from real events (currently manual-only).
5. Design system propagation: mobile's Business account-switcher,
   Contacts, Leads, Opportunities, and AI screens still only inherit
   the shared `ThemeData` — none individually redesigned yet. Web's AI
   screen likewise untouched.
6. Formal accessibility audit beyond color contrast (focus states,
   ARIA/semantics, keyboard nav, touch targets) and formal responsive
   QA at real breakpoints (attempted 2026-08-21, blocked by a browser
   tool limitation — window resize didn't reflect in screenshot
   capture — worth retrying with a different tool/approach).
7. Browser/component test runner for `apps/web`.
8. iOS source-parity audit (compare `apps/mobile/ios` config against
   `apps/mobile/android`, the way MORT's sessions did for that repo).

Owner-only, ask rather than attempt: `ANTHROPIC_API_KEY`, Google OAuth
credential creation, Supabase Auth redirect allow-list entries for the
real Preview/production URLs, a custom domain if wanted.

## Engineering loop (from CLAUDE.md, still the right process)

INSPECT → PLAN → BUILD → FORMAT → ANALYZE → TEST → RED TEAM → FIX →
RETEST → AUDIT → DOCUMENT → COMMIT → CONTINUE. Update
`docs/AUTONOMOUS_BUILD_STATUS.md`, `docs/KNOWN_ISSUES.md`,
`docs/LOOP_COMPLETION_LEDGER.md` as you go — they're the recovery
mechanism for the next interruption, the same way this file is.
