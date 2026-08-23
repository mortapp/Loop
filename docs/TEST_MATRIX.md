# LOOP Test Matrix

| Area | Test | Expected | Result | Evidence |
|---|---|---|---|---|
| Foundation | Initial verification | Repository structure exists | Pass | Repo inspected 2026-08-17 |
| Supabase local stack | `supabase start` / `db reset` applies all migrations 0001-0007 cleanly | No SQL errors | Pass | Local run 2026-08-17, all containers healthy |
| Identity | Sign up user → profile auto-created | 1 profile row matching auth.users id | Pass | REST smoke test 2026-08-17 |
| Identity | Sign up user → personal account auto-created | 1 `accounts` row, `type=personal`, `owner_profile_id` = user | Pass | REST smoke test 2026-08-17 |
| Identity | User creates a business (with `Prefer: return=representation`) | 201, business row returned, no RLS error | Pass (after fix — see docs/KNOWN_ISSUES.md) | REST smoke test 2026-08-17 |
| Identity | Business creation auto-provisions owner membership + business account | `business_members` has 1 `owner`/`active` row; `accounts` gains a `type=business` row | Pass | REST smoke test 2026-08-17 |
| RLS isolation | User B reads `items` while only User A has rows | Empty array, not an error | Pass | REST smoke test 2026-08-17 |
| RLS isolation | User B reads User A's `profiles` row by id (no shared business) | Empty array | Pass | REST smoke test 2026-08-17 |
| RLS isolation | User B reads User A's `businesses` (not a member) | Empty array | Pass | REST smoke test 2026-08-17 |
| Grants | Authenticated user inserts into `items`, `businesses`, `money_events` | Succeeds (previously `42501` before explicit GRANTs were added) | Pass (after fix — see docs/KNOWN_ISSUES.md) | REST smoke test 2026-08-17 |
| Ledger semantics | Insert into `money_events` | Succeeds, row returned | Pass | REST smoke test 2026-08-17 |
| pgTAP suite | All eight files in `supabase/tests/database` against the hosted schema, each in an isolated rollback transaction | All assertions pass with no fixture persistence | Pass — 128/128 | Suites 001-008, run 2026-08-23 |
| Fresh Supabase replay | Current CLI `2.115.0` `db reset --local` from empty, including roles bootstrap, every migration, and seed | Full history recreates without hosted-only helper assumptions | Pass | Clean reset, 2026-08-23; `supabase/roles.sql` compatibility shim runs before immutable migrations |
| Current pgTAP suite | All nine files in `supabase/tests/database` after the fresh reset | All account, quote, Today, Money, membership, username, storage, graph, and lifecycle assertions pass | Pass — 166/166 | Local current-schema run, 2026-08-23 |
| apps/web build | `lint` / `typecheck` / `build` from repo root | All pass | Pass | See docs/VERCEL_DEPLOYMENT.md "Build Verification" |
| apps/web runtime | `next dev`, unauthenticated `GET /`, `/today`, `/business` | 307 redirect to `/sign-in` (proxy.ts gating) | Pass | Manual curl against local dev server 2026-08-17 |
| apps/web runtime | `GET /sign-in` | 200, renders "LOOP" / "Sign in" | Pass | Manual curl 2026-08-17 |
| apps/mobile | `flutter analyze` / `dart format --set-exit-if-changed` / `flutter test` | All clean | Pass | Run 2026-08-17 |
| apps/web E2E | `npx playwright test` — 16 auth-guard specs (every `(app)/**` route + `/`, unauthenticated) | All redirect to `/sign-in`, no storage state used | Pass | Real run against local dev server, 2026-08-22 |
| apps/web E2E | `npx playwright test` — 17 authenticated specs (nav, Today, Money, Sell, Business, Protect, AI, account menu, personalization) | Self-skip cleanly without failing the run | Pass (skipped) | Real run, 2026-08-22 — needs `QA_TEST_EMAIL`/`QA_TEST_PASSWORD`, see docs/KNOWN_ISSUES.md (`OWNER_ACTION_REQUIRED`) |
| apps/mobile config contract | `SupabaseConfig.isValidConfig` — real URL, empty URL, empty key, placeholder host, non-https scheme, unparseable URL, no-host URL | Only real config accepted | Pass — 8/8 | `test/supabase_config_test.dart`, run 2026-08-22 |
| apps/mobile quote RPC | Atomic RPC parameter builder: totals, actor, normalized lines, empty/non-finite/negative rejection | One canonical payload; invalid values rejected before network | Pass — 3/3 | `test/features/business/quotes/quote_rpc_parameters_test.dart`, run 2026-08-23 |
| apps/mobile full suite | Auth/session, callback parity, onboarding disposal/large text, account persistence, safe errors, quote/lifecycle RPC payloads, return transitions, config, and shell behavior | All tests pass serially | Pass — 47/47 | `flutter test --no-pub --concurrency=1`, 2026-08-23 |
| Atomic money lifecycle | Purchases/listings/sales/refunds, ledger source uniqueness, state transitions, idempotency, privilege surface, and two-account isolation | Domain state and money state commit together; invalid/replayed/cross-account writes fail | Pass — 38/38 | `supabase/tests/database/009_atomic_money_lifecycle.sql`, 2026-08-23 |
| Business-member policy consolidation | Owner/admin/member/outsider/anon SELECT/INSERT/UPDATE/DELETE matrix after one-policy-per-command migration | Permissions unchanged and no self-escalation | Pass — 17/17 | `005_business_members_rls.sql`; advisor multiple-policy warnings reduced 2 to 0, 2026-08-23 |
| Hosted lifecycle schema | Latest migration, four invoker RPC grants, four private guards, 11 constraints, two unique indexes, four ordered triggers, direct sale-update grant | Exact expected metadata installed; anon/PUBLIC cannot execute RPCs | Pass | Read-only hosted catalog probes; ledger ends `20260823070326`, 2026-08-23 |
| apps/web safe errors | Static raw-error scan plus typecheck, ESLint, optimized build after server-action/AI/photo sanitization | No raw backend/provider `.message` rendered or returned; all gates pass | Pass | `rg`, `npm run typecheck`, `npm run lint`, `npm run build`, 2026-08-23 |
| Hosted account graph | Two synthetic accounts forge all nested contact/item/document/lead/opportunity/purchase/listing edges and actor IDs | Every foreign edge denied; actors derived from Auth | Pass — 32/32 | `supabase/tests/database/007_account_graph_integrity.sql`, rollback verified, 2026-08-23 |
| Hosted private Storage | Bucket privacy/limits/MIME/path RLS plus document metadata constraints | Cross-account/malformed paths denied; valid own paths work | Pass — 18/18 | `supabase/tests/database/008_private_storage.sql`, rollback verified, 2026-08-23 |
| Hosted quote integrity | Atomic header+lines, no orphans, totals recomputed, actor derived, direct-write constraints | All malformed/forged writes denied | Pass — 13/13 | `supabase/tests/database/002_quote_rpc.sql`, rollback verified, 2026-08-23 |
| apps/mobile OAuth (physical device) | Build with no `--dart-define`, install, launch, tap Continue with Google | App refuses to boot into sign-in; shows "LOOP can't start", clean logcat | Pass | Real Galaxy A14 run, 2026-08-22 |
| apps/mobile OAuth (physical device) | Build with `--dart-define-from-file=dart_define.json`, install, launch, tap Continue with Google | Opens `accounts.google.com`, "Choose an account to continue to zqalnvfwxmfrnyjcuehq.supabase.co" | Pass | Real Galaxy A14 run, 2026-08-22 — confirmed by screenshot; account selection not completed (owner's step) |
| apps/web accessibility | `accessibility.spec.ts` — axe-core WCAG2A/2AA on `/sign-in`, `/sign-up` | Zero violations | Pass | Real run against local dev server, 2026-08-22 |
| apps/web responsive | `responsive.spec.ts` — `/sign-in` at 360/390/430/768/1024/1280/1440px | No horizontal overflow at any width | Pass — 7/7 | Real run against local dev server, 2026-08-22 (Playwright `setViewportSize`, the working alternative to the broken Chrome `resize_window` tool) |

Method: local Supabase stack (`supabase/config.toml`, ports 55321-55329)
driven via raw `curl` against `/auth/v1` and `/rest/v1` with two
throwaway signed-up users, cross-checked with direct `psql` queries where
REST responses alone couldn't distinguish the root cause — now also
codified as an automated pgTAP suite (`supabase/tests/database/`) so it
runs as regression coverage, not just a one-off session. On 2026-08-23 all
eight suites were also run directly against the hosted schema; each request
began a transaction, used only synthetic fixtures, asserted TAP results, and
rolled back. Aggregate result: 128/128.

**2026-08-22**: real E2E coverage added (`apps/web/playwright.config.ts`,
`apps/web/e2e/`) — see docs/KNOWN_ISSUES.md for the full breakdown and
the OWNER_ACTION_REQUIRED gate on the authenticated specs (need a real
QA Supabase account this session cannot create itself).

**2026-08-21 CI gap found and fixed**: `.github/workflows/supabase-ci.yml`
ran `supabase db reset` (applies migrations + seed) but never actually
invoked `supabase test db`. The missing step was added. On 2026-08-23 a
second clean-replay defect was found: local CLI images do not contain the
hosted platform's `rls_auto_enable()` helper referenced by an immutable
migration. `supabase/roles.sql` now supplies an unattached local compatibility
function before migrations. A current-CLI reset and all 166 assertions pass,
so fresh CI no longer depends on a manually prepared local database.
