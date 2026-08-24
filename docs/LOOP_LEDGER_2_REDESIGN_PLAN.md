# LOOP Ledger 2.0 Redesign Ledger

## Verified baseline

- Start date: 2026-08-24
- Branch: `main`
- Start HEAD: `5b541eb26e7d5f84106aef69276633da9ea8a0c8`
- Mobile: Flutter in `apps/mobile`
- Web: Next.js in `apps/web`
- Android package: `com.loop.app.loop_mobile`
- Hosted Supabase project: `zqalnvfwxmfrnyjcuehq`
- MORT is read-only and outside this work.

The repository started with no tracked or staged changes. Preserved QA artifacts
and the pre-link Supabase directory were the only untracked paths.

## Product contract

LOOP is one private value ledger with five primary destinations:

1. Today
2. Money
3. Sell
4. Business
5. Ask LOOP

Protect remains part of Money. Business presents People, Work, and Quotes while
the existing contacts, leads, opportunities, and quotes data model remains
canonical. Account switching remains available through the account sheet.

## Non-regression boundary

This redesign changes presentation and navigation hierarchy only. It must not
weaken exact-decimal money handling, idempotency, server-authoritative quote
totals and status transitions, accepted-quote money events, RLS, account scope,
private storage, AI confirmation binding, PKCE, native callbacks, session
restoration, Today automation, or fail-closed provider behavior.

No existing migration is edited. No destructive schema action is authorized.
No duplicate providers, repositories, or versioned replacement screens will be
created.

## Delivery checkpoints

| Checkpoint | Status | Evidence |
| --- | --- | --- |
| Repository and architecture recovery | Complete | HEAD and worktree verified; canonical routes/providers inventoried |
| Mobile ledger primitives and five-destination shell | Complete | Shared data-agnostic ledger primitives; Ask LOOP is the fifth destination |
| Today simplification | Complete | One next action, up to four compact rows, quiet `You are clear` state |
| Money and Protect integration | Complete | Value hero, Made/Protected/Recovered, ledger, Add entry sheet, Protect row |
| Sell simplification | Complete | Recovery hero, Add Item sheet, inventory tiles, one state-based primary action |
| Business simplification | Complete | People/Work/Quotes summaries use existing live providers and routes |
| Ask LOOP and account simplification | Complete | Private-counsel language and Account/Profile/Appearance/Help/Sign out menu |
| Native onboarding simplification | Complete | One calm form; verified email, name, username, conditional secure password |
| Mobile regression | Complete | All 22 Flutter test files pass serially; analyzer clean |
| Physical Samsung QA | Pending | Wireless ADB transport currently unavailable |
| Web parity | Complete | Five-destination ledger UI uses existing server actions and account-scoped reads |
| Final security, build, and release evidence | Pending | No release claim until current gates pass |

## External or current gates

- Wireless ADB: the previous endpoint no longer answers and mDNS currently
  discovers no Samsung. Continue source work; reconnect when the device is
  visible. Fresh pairing is requested only if ADB confirms it is required.
- Ask LOOP provider: remains fail-closed until the server-side provider key is
  configured. The UI must report this truthfully.
- Google credential interaction: owner-only when a physical sign-in prompt is
  reached. Credentials and tokens must never be read or logged.

## Checkpoint 1 verification

- `flutter analyze --no-pub`: PASS, no issues.
- Focused shell, Business, account-sheet, and Ask LOOP security tests: PASS,
  23 tests.
- Galaxy A14 widget profile at 100% and 150% text: PASS.
- One initial parallel Flutter test run was interrupted by a Windows/OneDrive
  test-cache `PathExistsException`; the exact suite passed when rerun with
  `--concurrency=1`.
- Database, RPC, provider, migration, and auth implementations were not changed.

## Current phase

Configured Android build and physical-device verification. Mobile onboarding
retains username checks, credential binding, safe errors, and focus recovery.
Sell retains exact money parsing, private photos, and canonical lifecycle RPCs.
Every one of the 22 Flutter test files passes when run independently, avoiding a
Windows/OneDrive compiler-cache collision in the parallel runner.

## Web parity verification

- `npm run lint`: PASS.
- `npm run typecheck`: PASS.
- `npm run test:unit`: PASS, 4 tests.
- `npm run build`: PASS, 24 routes generated.
- `npm run test:e2e`: PASS for all executed tests, 31 passed and 60 skipped.
- The 60 skipped tests require `QA_TEST_EMAIL` and `QA_TEST_PASSWORD`; neither is
  present in process or User-scope environment. No credential was fabricated.
- Public accessibility, responsive behavior, auth guards, bearer-token API
  boundaries, AI confirmation binding, and idempotency tests executed and passed.
- Authenticated web journeys remain an explicit QA-credential gate.
