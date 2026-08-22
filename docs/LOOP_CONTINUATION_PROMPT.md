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

**The design system is "Murex Noir", not "Ledger"** — read
docs/DESIGN_SYSTEM.md before touching any UI. "Ledger" (mint green)
and "Imperial Verdigris" (aged-copper teal) were both tried and
rejected the same day; Murex Noir (blackened royal ink — near-black
with a Tyrian identity hue, Royal Bone text, rare Champagne/Ruby
accents) is locked in and fully propagated on both platforms — do not
restore either predecessor or invent a new one.

Done: schema + RLS + storage (now 2 buckets: `documents`,
`item-photos`) on the real hosted project, both apps' five product
areas real and functional including mobile Warranties and item photo
upload, CI runs real test suites, Murex Noir fully propagated (nav
rail, Money hero, Sell gallery, Business, AI — zero remaining
old-token/raw-Tailwind screens), Google Sign-In verified live on both
platforms (in earlier sessions), RLS/perf hardening (auth.uid()
initplan wrapping + missing FK indexes) this session.

Not done, no owner action needed — just pick one and go:
1. **Account identity** — menu, profile, personalization, settings,
   help. Entirely unbuilt on both platforms; this is the largest
   single remaining body of work. See sections 8–14 of whatever
   continuation directive prompted the most recent session for the
   exact UX spec (ChatGPT-inspired account menu pattern, Murex Noir
   materials, no billing/subscription states unless LOOP has a real
   reason for them).
2. Today auto-population from real events (currently manual-only).
3. Money integrity tests — prove no double-counting across
   MADE/PROTECTED/RECOVERED/net, not just "reads from one ledger."
4. Mobile quote creation → swap to `create_quote_with_line_items` RPC
   (mobile still has the two-step race web used to have).
5. AI mobile surface, or more AI tools, or streaming (all reasonable
   Phase 8 depth work) — AI backend engineering itself is done, only
   blocked on `ANTHROPIC_API_KEY` for live verification.
6. Formal accessibility audit beyond contrast + the icon-only-nav
   accessible-name fix made 2026-08-22 (keyboard nav, focus traps,
   screen-reader pass, touch targets) and formal responsive QA on
   authenticated pages at the full breakpoint set.
7. Browser/component test runner for `apps/web`.
8. Broader iOS source-parity audit (one gap already found and fixed:
   `NSPhotoLibraryUsageDescription`) — compare the rest of
   `apps/mobile/ios` config against `apps/mobile/android`.
9. `business_members`'s overlapping RLS policies (performance-only,
   deliberately deferred — needs pgTAP coverage to verify against
   first; see docs/KNOWN_ISSUES.md).

**Real, current, non-fabricated blocker as of 2026-08-22**: nothing in
the app can be visually/functionally verified past the sign-in screen,
on either platform, without a real authenticated session — this
session's safety classifier correctly refuses to type a password into
any field itself, browser or on-device. A human signing in once (or a
new non-password auth path being built, e.g. magic link) unblocks a
lot of QA at once.

Owner-only, ask rather than attempt: `ANTHROPIC_API_KEY`, leaked-
password-protection toggle (Supabase Auth dashboard), a custom domain
if wanted.

## Engineering loop (from CLAUDE.md, still the right process)

INSPECT → PLAN → BUILD → FORMAT → ANALYZE → TEST → RED TEAM → FIX →
RETEST → AUDIT → DOCUMENT → COMMIT → CONTINUE. Update
`docs/AUTONOMOUS_BUILD_STATUS.md`, `docs/KNOWN_ISSUES.md`,
`docs/LOOP_COMPLETION_LEDGER.md` as you go — they're the recovery
mechanism for the next interruption, the same way this file is.
