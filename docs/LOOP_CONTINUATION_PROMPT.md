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

Done, as of `ca3fc42` (2026-08-22): schema + RLS + storage on the real
hosted project, both apps' five product areas real and functional,
account identity (menu/profile/personalization/settings/help) on both
platforms, mobile Ask LOOP AI client, idempotent Today automation,
canonical Money integrity with a real zero/negative constraint, a
Playwright E2E harness (45 tests, 25 running for real), scoped
accessibility fixes + automated axe scans, responsive QA at all 7
breakpoints, a real `business_members` privilege-escalation bug found
and fixed, a full iOS source-parity audit (which found and fixed a real
Android release-manifest bug), and a verified-live Vercel production
deployment. Full detail: docs/LOOP_COMPLETION_LEDGER.md.

**Not done, no owner action needed** — the one item on the ledger that
is genuine unstarted engineering rather than an owner/external gate:
1. **Mobile accessibility** — no Flutter `Semantics`/focus/touch-target
   audit has been done at all (`ACCESSIBILITY_MOBILE=FAIL` on the
   ledger). Web's axe-core + manual-fix pass has no mobile equivalent
   yet.

Smaller, real, lower-priority follow-ups (none blocking):
- Web accessibility beyond the current scoped pass: manual keyboard-
  only walkthrough, touch-target sizing, text-scaling stress test.
- Native splash-screen branding on both platforms (currently both
  equally stock/unbranded — real parity, just not yet Murex Noir).
- AI depth once `ANTHROPIC_API_KEY` exists: more tools, streaming.

**Real, current, non-fabricated blocker as of 2026-08-22**: nothing in
the app can be visually/functionally verified past the sign-in screen,
on either platform, without a real authenticated session — this
session's safety rules correctly refuse to type a password into any
field itself, browser or on-device (checked via read-only screenshot
repeatedly, not assumed). A human signing in once (physical device
and/or production web) unblocks a lot of QA at once — the full matrix
and the 20 gated Playwright specs are ready to run immediately after.

Owner-only, ask rather than attempt: `ANTHROPIC_API_KEY`, leaked-
password-protection toggle (Supabase Auth dashboard), a dedicated QA
Supabase Auth account + `QA_TEST_EMAIL`/`QA_TEST_PASSWORD` as GitHub
Actions secrets (see docs/KNOWN_ISSUES.md for the exact 2 steps), a
custom domain if wanted.

## Engineering loop (from CLAUDE.md, still the right process)

INSPECT → PLAN → BUILD → FORMAT → ANALYZE → TEST → RED TEAM → FIX →
RETEST → AUDIT → DOCUMENT → COMMIT → CONTINUE. Update
`docs/AUTONOMOUS_BUILD_STATUS.md`, `docs/KNOWN_ISSUES.md`,
`docs/LOOP_COMPLETION_LEDGER.md` as you go — they're the recovery
mechanism for the next interruption, the same way this file is.
