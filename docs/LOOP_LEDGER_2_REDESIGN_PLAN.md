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
| Sell simplification | Pending | Inventory-first rows and state-based actions |
| Business simplification | Complete | People/Work/Quotes summaries use existing live providers and routes |
| Ask LOOP and account simplification | Complete | Private-counsel language and Account/Profile/Appearance/Help/Sign out menu |
| Mobile regression and physical Samsung QA | Pending | Wireless ADB transport currently unavailable |
| Web parity | Pending | Reuse current app shell and server actions |
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

Sell and onboarding simplification. The next automatic verification gate is
focused form and large-text coverage, followed by the full mobile suite and a
configured APK for the connected Samsung when transport is restored.
