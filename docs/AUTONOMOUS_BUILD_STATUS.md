# LOOP Autonomous Build Status

## Current Phase

All internally controllable engineering work from the "FINAL
RELEASE-CANDIDATE COMPLETION" directive is done as of commit `ca3fc42`.
See docs/LOOP_COMPLETION_LEDGER.md for the full, current status matrix
— this file is a short pointer, not a duplicate of it. What remains is
entirely owner/external-gated: `ANTHROPIC_API_KEY`, the leaked-password
dashboard toggle, a dedicated QA Supabase account for the authenticated
half of the Playwright suite, a human sign-in on the physical Galaxy
A14 (and on production web) for authenticated QA, and macOS/Xcode for
a real iOS build. `LOOP_FINAL_STATE=PRODUCTION_READY_EXTERNALLY_BLOCKED`.

## Completed this session (continuing from `b12c6b8`)

- **Mobile Ask LOOP client** — real Flutter chat UI calling the exact
  same `/api/ai/chat`+`/api/ai/confirm` backend web uses, via a new
  dual-transport auth boundary (`apps/web/src/lib/ai/auth.ts`).
- **Today automation** — `public.generate_today_actions`, idempotent
  via a real DB constraint, 12 pgTAP assertions.
- **Money integrity** — `public.account_money_totals`, one canonical
  formula for both platforms, a real zero/negative CHECK constraint,
  10 pgTAP assertions.
- **Playwright E2E harness** — 45 tests, 25 running for real with no
  credentials (auth guards, responsive, public-page accessibility).
- **Accessibility** — 2 real bugs fixed (account-menu accessible name,
  duplicate id) + 3 unlabeled forms fixed, automated axe-core scans.
- **Responsive QA** — all 7 breakpoints verified live via Playwright
  `setViewportSize`, the working alternative to the broken
  `resize_window` browser tool.
- **`business_members` security fix** — found and fixed a real
  privilege-escalation bug (self-insert-as-owner, self-role-promotion),
  17 pgTAP assertions.
- **iOS source-parity audit** — full static/config comparison; found
  and fixed a real Android release-build bug along the way (missing
  `INTERNET` permission in `main/AndroidManifest.xml`).
- **Full regression** — web lint/typecheck/build/E2E, mobile
  format/analyze/test/build (debug + release), CI workflow validation,
  live production smoke test.

## Blocked (owner/external only)

- `ANTHROPIC_API_KEY` — both AI clients are built and ready; neither
  can be live-verified without it.
- Leaked-password protection — Supabase Auth dashboard toggle.
- QA Supabase account for the 20 authenticated Playwright specs —
  creating an account (even an isolated QA one) is outside what this
  session does; see docs/KNOWN_ISSUES.md for the exact 2-step setup.
- A human sign-in on the physical Galaxy A14 and on production web —
  this session's safety rules correctly refuse to type a password into
  any field; checked via read-only screenshot, not assumed.
- iOS real build/TestFlight — needs macOS/Xcode.

## Last Known Good Commit

`ca3fc42` — "fix(mobile): add missing INTERNET permission to the
Android release manifest". Pushed; `origin/main` matches local `main`.
This session's commits (newest first):

```
ca3fc42  fix(mobile): add missing INTERNET permission to the Android release manifest
b12c6b8  fix(security): close a real business_members privilege-escalation hole
055da3f  test(web): responsive QA at 360/390/430/768/1024/1280/1440px via Playwright
c96370d  fix(a11y): real accessible-name and label gaps + automated axe coverage
3f89a31  test(web): real Playwright E2E harness
0a9fde0  feat(money): canonical MADE/PROTECTED/RECOVERED/SPENT/FEES/NET
756500c  feat(today): idempotent auto-generated actions
a0ab6fd  feat(ai): real mobile Ask LOOP client on the shared web AI backend
```

## Next Action

Nothing internally controllable remains queued. When an owner action
above is completed, the corresponding work resumes automatically (the
Playwright specs and Galaxy A14 QA matrix are both ready to run the
moment credentials/a session exist — no code changes needed).
