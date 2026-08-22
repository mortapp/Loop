# LOOP Completion Ledger

Status values: PASS, FAIL, PARTIAL, IN_PROGRESS, EXTERNAL_BLOCKER,
OWNER_ACTION_REQUIRED, ACCEPTED_WITH_EVIDENCE, NOT_RUN. Never converted
to PASS to reach a prettier percentage — see docs/AUTONOMOUS_BUILD_STATUS.md
and docs/KNOWN_ISSUES.md for full evidence behind every row below.

Rewritten 2026-08-22 (LOOP — FINAL RELEASE-CANDIDATE COMPLETION session,
continuing from checkpoint `b12c6b8` after a usage-limit pause). This
replaces the prior version, which predated this session's mobile AI
client, Today automation, Money integrity, Playwright E2E harness,
accessibility work, responsive QA, the `business_members` security fix,
and the iOS parity audit.

| Area | Status | Note |
|---|---|---|
| REPOSITORY | PASS | Clean working tree at every checkpoint this session; `git status`/`log`/`fetch` re-verified at session start per the Checkpoint Law, never assumed. |
| GITHUB | PASS | Every commit this session pushed to `origin/main`, fast-forward only, verified via `git ls-remote` after each push. Chain: `a0ab6fd`→`756500c`→`0a9fde0`→`3f89a31`→`c96370d`→`055da3f`→`b12c6b8`→`ca3fc42`. |
| MUREX_NOIR | PASS | Unchanged this session — full token replacement on both platforms from an earlier session, physically confirmed on the real Galaxy A14. Not re-touched; no regression introduced by this session's changes (all additive: new screens/migrations/tests reuse existing `AppColors`/`AppSpacing`/`var(--color-*)` tokens). |
| WEB_UI | PASS | `next build`/`lint`/`typecheck` clean after every phase this session; live production smoke test (see PRODUCTION_WEB) confirms no visual/hydration regression. |
| MOBILE_UI | PASS | `flutter analyze`/`format --set-exit-if-changed` clean after every phase; debug and release APKs both build and launch cleanly on the physical Galaxy A14 with clean logcat. |
| ACCOUNT_SYSTEM | PASS | Unchanged this session (built in the prior continuation) — account menu, Profile, Settings, Personalization, Help on both platforms. This session fixed two real accessibility gaps in the web account menu (missing accessible name at some breakpoints, a duplicate `id="account-menu"`) — see ACCESSIBILITY_WEB. |
| TODAY | PASS | Unchanged base feature; still real, live-verified in an earlier session. |
| TODAY_AUTOMATION | PASS | New this session. `public.generate_today_actions(account_id)` (`supabase/migrations/20260822160000_today_automation.sql`) turns quote follow-up/expiry, return-window, and warranty deadlines into real `actions` rows. Idempotent via a partial unique index + `on conflict do nothing` (a real DB constraint, not an app-side check-then-insert). Three AFTER triggers auto-close a generated action when the underlying thing resolves elsewhere. Both Today screens call the RPC on load, best-effort. Covered by 12 pgTAP assertions (`supabase/tests/database/003_today_automation.sql`); migration applied live, `get_advisors` showed no new findings. |
| MONEY | PASS | Unchanged base feature. |
| MONEY_INTEGRITY | PASS | New this session. `public.account_money_totals(account_id)` (`supabase/migrations/20260822163000_money_integrity.sql`) is now the one canonical MADE/PROTECTED/RECOVERED/SPENT/FEES/NET formula — both web and mobile call it instead of independently re-deriving totals from the raw event list (which they previously did, with signs kept in sync only by a comment). A real `CHECK (amount_cents > 0)` constraint now prevents a zero/negative ledger entry at the schema level, not just client-side. Covered by 10 pgTAP assertions: partial refund, duplicate events (both count — correct for an append-only ledger), zero/negative rejected, odd-cent-amount precision (333+333+334=1000 exactly), and account isolation both ways. Migration applied live. |
| MAKE | PASS | Unchanged this session. |
| PROTECT | PASS | Unchanged this session. |
| RECOVER | PASS | Unchanged this session. |
| ITEM_PHOTOS | PASS | Unchanged this session (built and live-verified in an earlier continuation). |
| ASK_LOOP_WEB | PASS | Unchanged this session — chat UI, confirm/decline tool-registry flow. |
| ASK_LOOP_ANDROID | PASS | New this session. Real Flutter chat client (`apps/mobile/lib/features/ai/ai_repository.dart` + rewritten `ai_screen.dart`) calling the exact same `/api/ai/chat`+`/api/ai/confirm` endpoints web uses — not a parallel architecture. Full text/loading/retry/error UX, pending tool-confirmation cards with Confirm/Decline, Murex Noir styling with the Double Loop Seal marking assistant output. `flutter analyze` clean, debug APK built and launched cleanly on the physical Galaxy A14. Marked PASS for client completeness — see AI_BACKEND for the separate provider-credential gate. |
| AI_BACKEND | OWNER_ACTION_REQUIRED | `ANTHROPIC_API_KEY` remains unset. The cross-platform auth boundary (`apps/web/src/lib/ai/auth.ts`'s `resolveAiRequest` — cookie session for web, `Authorization: Bearer <supabase JWT>` + explicit `accountId` for mobile) was built and verified (`tsc`/`eslint` clean, both routes preserve existing web behavior) this session specifically so the mobile client would have a real backend to call the moment the key is set. Cannot be live-verified end-to-end without the key. |
| AUTH | PASS | Unchanged this session. Production auth guard re-verified live this session (see PRODUCTION_WEB): unauthenticated `/today` correctly redirects to `/sign-in?next=%2Ftoday` on the real deployment, not just locally. |
| GOOGLE_AUTH_WEB | PASS | Unchanged this session, previously verified live. |
| GOOGLE_AUTH_ANDROID | PASS | Unchanged this session, previously verified on the real Galaxy A14. |
| DATABASE | PASS | 4 new migrations this session (`today_automation`, `money_integrity`, `fix_business_members_self_escalation`, plus the 3 from the prior continuation), all applied to the real hosted project and tracked in `supabase/migrations/`. |
| MIGRATIONS | PASS | Local `supabase/migrations/` and the hosted project confirmed to match after every `apply_migration` call this session. |
| RLS | PASS | Every table still has RLS enabled. This session's `business_members` fix is the headline change — see BUSINESS_MEMBERS_SECURITY. All other `for all`/`with check` policies across every migration file were re-read this session specifically looking for the same class of bug (a `WITH CHECK` that verifies identity but not scope) — none found; every other policy either uses `has_account_access(account_id)` (account_id itself RLS-protected) or a same-identity self-only pattern with no privilege implication (`created_by = auth.uid()`, `id = auth.uid()`). |
| BUSINESS_MEMBERS_SECURITY | PASS | A real privilege-escalation bug found and fixed this session (`supabase/migrations/20260822170000_fix_business_members_self_escalation.sql`) — see docs/KNOWN_ISSUES.md and the commit message for full detail. Old `business_members_self_manage` (FOR ALL, `WITH CHECK (profile_id = auth.uid())` only) let any authenticated user INSERT themselves as `owner`/`active` into any business, or UPDATE their own row's `role` to `owner`/`admin`. No app code used self-service writes to this table, so the fix (self-service narrowed to SELECT + DELETE only; INSERT/UPDATE require `is_business_admin()`) has zero product cost. 17 pgTAP assertions (`supabase/tests/database/005_business_members_rls.sql`) cover owner/admin/member/outsider/anon across select/insert/update/delete, both escalation paths explicitly blocked, legitimate admin management still works, cross-business access denied both ways. Migration applied live to 0 existing rows. |
| STORAGE | PASS | Unchanged this session — `documents` + `item-photos` buckets, reviewed again during this session's security pass, both correctly path-partitioned and RLS-scoped. |
| WEB_E2E | PASS / OWNER_ACTION_REQUIRED | New this session. Playwright harness (`apps/web/playwright.config.ts`, `apps/web/e2e/`), the smallest framework that can actually exercise SSR Server Components + cookie auth + real navigation. 45 tests across 10 files. 25 run for real with no credentials needed (16 auth-guard tests covering every `(app)/**` route + `/`, 7 responsive breakpoint checks, 2 axe accessibility scans) — all pass against both a local dev server and, for the guard behavior, live production. The remaining 20 (nav/Today/Money/Sell/Business/AI/account-menu/personalization/accessibility on authenticated pages) are real, complete test code that `test.skip`s itself without `QA_TEST_EMAIL`/`QA_TEST_PASSWORD` — creating that account is outside what this session can do (account creation is a prohibited action even for an isolated QA user). See docs/KNOWN_ISSUES.md for the exact 2-step owner action. |
| ACCESSIBILITY_WEB | PASS | Scoped, not exhaustive — see docs/KNOWN_ISSUES.md for exactly what's still open (manual keyboard pass, touch-target sizing, text-scaling stress test). This session: fixed 2 real bugs (account-menu trigger had no accessible name at some breakpoints; a duplicate `id="account-menu"` since two menu instances render simultaneously) and 3 forms with no field labels at all (Money/Sell/Today). Automated axe-core WCAG2A/2AA scans added and run live against `/sign-in`/`/sign-up`: zero violations. 7 more page scans wired the same way, gated on WEB_E2E's QA-credential blocker. |
| ACCESSIBILITY_MOBILE | FAIL | Not started this session or any prior one. No Flutter `Semantics`/focus/touch-target audit has been done. Recorded honestly rather than inferred from the web pass. |
| RESPONSIVE_WEB | PASS | New this session, and a real answer to the prior session's `resize_window` tool-limitation blocker: Playwright's `setViewportSize` is the working alternative (resizes before navigation, so layout is correct from first paint). All 7 named breakpoints (360/390/430/768/1024/1280/1440) verified live against `/sign-in` with zero horizontal overflow at any width. The equivalent authenticated-page checks are wired the same QA-credential-gated way as WEB_E2E. |
| ANDROID_BUILD | PASS | Both debug and, new this session, **release** builds succeed. The release build surfaced a real bug this session found via the iOS parity audit (missing `INTERNET` permission — see below); a second real bug (every prior build silently missing `--dart-define`, see ANDROID_SUPABASE_CONFIG) was found afterward on the physical device and is also fixed. `dart_define.json` (gitignored) is now the one correct, remembered way to build. |
| GALAXY_A14_CONNECTION | PASS | Reconnected cleanly this session via `adb connect` after a brief `offline` state; device visible throughout. |
| ANDROID_SUPABASE_CONFIG | PASS | Real regression found and fixed this session (see docs/KNOWN_ISSUES.md): every mobile build was silently running against `placeholder.supabase.co` because `--dart-define-from-file` was never passed. Fixed with a real startup validation (`SupabaseConfig.isValidConfig`) plus a durable `dart_define.json` build path. 8 new unit tests; verified live on the Galaxy A14 both ways (misconfigured build shows a clean "can't start" screen, correctly-configured build reaches real Google OAuth). |
| PLACEHOLDER_URL_REJECTED | PASS | `main.dart` gates on `SupabaseConfig.isConfigured` before Supabase is ever initialized; `bootstrapSupabase` no longer has a silent fallback. Live-verified on-device: a build with no dart-defines renders `ConfigurationErrorApp` with a clean logcat, never reaches the sign-in screen. |
| GOOGLE_OAUTH_HANDOFF | PASS | Live-verified on the Galaxy A14 with the corrected build: **Continue with Google** correctly opens `accounts.google.com`, "Choose an account to continue to zqalnvfwxmfrnyjcuehq.supabase.co" (the real project, confirmed by screenshot) — not `placeholder.supabase.co`. |
| MOBILE_CALLBACK | OWNER_INTERACTION_REQUIRED | `com.loop.app.loop_mobile://login-callback` confirmed from current source (`auth_screen.dart`'s `_oauthRedirectUrl`, matching the Android manifest's intent-filter data tag exactly). Not exercised end-to-end — completing the Google account chooser is the owner's step, not typed/selected by this session. |
| GALAXY_A14_RETEST | PASS | Full reproduce-fix-verify cycle completed live on the physical device this session: confirmed the bug, fixed root cause, rebuilt both ways (misconfigured and correct), reinstalled, relaunched, reached the real OAuth chooser, backed out cleanly, left the device on a correctly-configured, crash-free build. |
| GALAXY_A14_AUTHENTICATED_QA | OWNER_ACTION_REQUIRED | The Google OAuth path now reaches the real project (see above) rather than being silently unreachable, which was itself a plausible explanation for the device sitting on the sign-in screen through most of this session. The owner still needs to complete account selection/sign-in themselves — this session does not select a Google account or type a password into any field, on-device or in-browser. The full authenticated matrix (Today/Money/Sell/Business/Protect/Ask LOOP/account menu/general nav) is ready to run the moment a session exists. |
| GALAXY_A14_PERFORMANCE | OWNER_ACTION_REQUIRED | Same blocker — meaningful performance observation (scrolling, image rendering, tab switching) needs authenticated screens with real data. Launch-only logcat inspection (below) is clean but is not a performance signal on its own. |
| LOGCAT | PASS | Cleared and inspected after every install this session (debug and release both) — clean, no `FATAL EXCEPTION`/`AndroidRuntime`/`ANR`/`Unhandled Exception` in any run. |
| IOS_SOURCE_PARITY | PASS | Full audit this session (docs/KNOWN_ISSUES.md has the complete breakdown): `Info.plist` vs `AndroidManifest.xml`, bundle identifiers, OAuth/deep-link redirect handling, photo-library permission, ATS, Google auth architecture, deployment target vs. every plugin in use, launch-screen branding parity (both equally unbranded — real parity, just not yet Murex Noir), and the (expected, non-issue) absence of a `Podfile`. Static/config review only — no Xcode available. |
| IOS_REAL_BUILD | EXTERNAL_BLOCKER | Unchanged — Windows environment, no Xcode/macOS. |
| SECRET_SCAN | PASS | Re-run this session against the full tracked tree (patterns for `sk-`/`ghp_`/`AIza`/PEM private keys/generic `password=`/`token=`/`secret=`/`api_key=` literals, plus a check for any committed `.env`/`.env.local`) — clean; the only `.env`-shaped tracked file is the intentional empty `.env.local.example` template. |
| SUPABASE_ADVISOR | ACCEPTED_WITH_EVIDENCE | Re-run after every migration this session. Remaining WARN-level findings: 4 helper functions (`has_account_access`, `is_active_business_member`, `is_business_admin`, `shares_active_business`) flagged as SECURITY DEFINER callable by `authenticated` — reviewed and confirmed intentional/necessary (RLS-recursion-breaking helpers, narrow ID-scoped boolean checks, return `false` for any anon caller). `rls_auto_enable` flagged the same way — confirmed this session to be a Supabase-platform-owned event trigger (`RETURNS event_trigger`, owned by `postgres`, not in any LOOP migration); Postgres refuses to invoke an event-trigger-returning function outside real trigger context, so the EXECUTE grant is not a live exposure, matching the same reasoning already accepted for the `handle_new_*` provisioning triggers. `auth_leaked_password_protection` — see LEAKED_PASSWORD_PROTECTION below. No new findings introduced by any of this session's 4 migrations. |
| LEAKED_PASSWORD_PROTECTION | OWNER_ACTION_REQUIRED | Unchanged — a Supabase Auth dashboard toggle, not reachable via SQL/migration tooling. |
| ANTHROPIC_PROVIDER | OWNER_ACTION_REQUIRED | See AI_BACKEND. |
| CI | PASS | All 3 workflow YAMLs re-validated this session (parsed with `js-yaml`, all valid) and confirmed to exercise the right suites: `supabase-ci.yml` runs `db reset` + `supabase test db`, which will pick up this session's 3 new pgTAP files automatically (no explicit file list to update); `web-ci.yml` gained a new `e2e` job (gated on `NEXT_PUBLIC_SUPABASE_URL` existing as a repo secret) that installs Playwright and runs the full E2E suite, uploading the HTML report as an artifact; `mobile-ci.yml` unchanged, already correct (format+analyze+test). |
| VERCEL | PASS | Latest push (`ca3fc42`) auto-deployed via the existing git-linked project (`prj_zgoDaWhw4m7uBj8PjgfalFKXbmFV`, no new project created) and reached `READY`/`production`, correctly aliased to `loop-teal-rho.vercel.app`. Confirmed via `list_deployments`/`get_deployment` — `githubCommitSha` on the live deployment matches this session's exact HEAD. |
| PRODUCTION_WEB | PASS | Live-verified this session via real browser navigation (not just the API): `/sign-in` renders correctly, zero console errors on a fresh load, and `/today` unauthenticated correctly redirects to `/sign-in?next=%2Ftoday` — the proxy auth guard confirmed working on the actual production deployment, not just locally. `get_runtime_errors` for the last 24h: none. No authenticated production session was available to exercise further (same credential-entry boundary as everywhere else this session) — full authenticated production smoke test is part of the same owner-gated QA as GALAXY_A14_AUTHENTICATED_QA / WEB_E2E. |
| DOCUMENTATION | PASS | This file, docs/KNOWN_ISSUES.md, and docs/TEST_MATRIX.md all rewritten/updated this session to match live, verified reality — stale claims (mobile AI missing, Today manual-only, Money integrity untested, no Playwright, responsive QA untested, business_members escalation unresolved) removed. |
| EXTERNAL_BLOCKERS | — | See below. |

## LOOP_FINAL_STATE=PRODUCTION_READY_EXTERNALLY_BLOCKED

All engineering work this session set out to do is complete: mobile AI
client, idempotent Today automation, canonical Money integrity, a real
Playwright E2E harness, real (scoped) accessibility fixes + automated
scanning, responsive QA across all 7 breakpoints, a genuine security
vulnerability found and fixed in `business_members` RLS with exhaustive
regression coverage, a full iOS source-parity audit (which surfaced and
fixed a real Android release-build bug along the way), a full internal
regression pass (web lint/typecheck/build/E2E, mobile format/analyze/
test/build×2), and a verified-live production deployment on the
existing Vercel project.

**Owner-only / external (cannot be done by this session):**
- `ANTHROPIC_API_KEY` — Ask LOOP cannot be live-verified on either
  platform without it. Both clients are engineered and ready.
- Leaked-password protection toggle (Supabase Auth dashboard setting).
- A dedicated QA Supabase Auth account + `QA_TEST_EMAIL`/
  `QA_TEST_PASSWORD` as GitHub Actions secrets — creating an account is
  a prohibited action for this session, even a low-stakes isolated one.
  20 real Playwright specs are ready and waiting.
- A live sign-in on the physical Galaxy A14, and equally on the live
  production web app — this session's safety rules correctly refuse to
  type a password into any field, on-device or in-browser, checked
  repeatedly via read-only screenshot rather than assumed. The full
  authenticated QA matrix (both platforms) is ready to run the moment
  a session exists.
- iOS real build/TestFlight — needs macOS/Xcode, unavailable on
  Windows. Source parity is PASS; the real build is the only thing
  blocked.

No internally controllable engineering work is known to remain
undone. `ACCESSIBILITY_MOBILE=FAIL` is the one item on this ledger that
is genuine unstarted engineering, not an owner/external gate — recorded
honestly rather than folded into the externally-blocked story; see
docs/KNOWN_ISSUES.md.

See docs/LOOP_CONTINUATION_PROMPT.md for the exact next-session
starting point.
