# LOOP Completion Ledger

Status values: PASS, FAIL, IN_PROGRESS, EXTERNAL_BLOCKER,
OWNER_ACTION_REQUIRED, NOT_RUN. Never converted to PASS to reach a
prettier percentage — see docs/AUTONOMOUS_BUILD_STATUS.md and
docs/KNOWN_ISSUES.md for full evidence behind every row below.

Rewritten 2026-08-22 (LOOP — MUREX NOIR continuation session) — the
previous version of this file predated the Murex Noir rebrand entirely
and described the superseded "Ledger" (mint green) design system as
current. Read docs/DESIGN_SYSTEM.md for the full design history
("Ledger" → "Imperial Verdigris" → "Murex Noir", all same day).

| Area | Status | Note |
|---|---|---|
| POWER_LOSS_RECOVERY | PASS | Repo inspected fresh at the start of each of this session's continuations; source of truth is `git status`/`log`, never assumed. |
| MUREX_NOIR | PASS | Full token replacement on both platforms, WCAG-computed (see docs/DESIGN_SYSTEM.md). Physically confirmed on the real Galaxy A14: near-black, not purple; Champagne rare; Royal Bone warm. |
| DESIGN_PROPAGATION | PASS | Every screen migrated off raw Tailwind/old tokens (verified by grep — zero remaining zinc/emerald/amber/purple literals). Web nav is now a vertical rail; Money has the hero treatment; Sell is a real image gallery; Business's contacts/leads/opportunities (previously literally unthemed, not just wrong-themed) rebuilt; AI is "Ask LOOP". |
| ACCOUNT_IDENTITY | FAIL | Not started this session — no account menu, profile, personalization, settings, or help surface exists on either platform yet. Real, scoped follow-up work (sections 8–14 of the continuation directive). |
| ACCOUNT_MENU_WEB | FAIL | Not started. |
| ACCOUNT_MENU_MOBILE | FAIL | Not started. |
| PROFILE | FAIL | Not started. |
| PERSONALIZATION | FAIL | Not started. |
| SETTINGS | FAIL | Not started. |
| HELP | FAIL | Not started. |
| SIGN_OUT | PASS | Pre-existing (`signOut()` web Server Action, mobile's Supabase `auth.signOut()`), unchanged this session; code-reviewed, not re-verified live against a real session (see AUTHENTICATED QA blocker in docs/KNOWN_ISSUES.md). |
| ACCOUNT_SWITCHING | PASS | Pre-existing, RLS-enforced via `has_account_access()`, not merely client-trusted — code + RLS reviewed this session, not changed. |
| AUTH | PASS | Email/password real on both platforms; unchanged this session. |
| GOOGLE_AUTH_WEB | PASS | Verified live end-to-end in an earlier session (commit `07e5318`) through the real `accounts.google.com` consent screen with the correct client ID/redirect. Not re-verified this session (no new browser auth attempted — see AUTHENTICATED QA blocker). |
| GOOGLE_AUTH_ANDROID | PASS | Verified on the real Galaxy A14 in an earlier session (`ab846c3`) — OAuth handoff reaches `accounts.google.com` targeting the correct project, cancel path returns cleanly. Not re-attempted this session (same auth-classifier constraint applies to any further on-device interaction with the sign-in screen — see docs/KNOWN_ISSUES.md). |
| TODAY | PASS | Real actions queue, unchanged this session. |
| TODAY_AUTOMATION | FAIL | Still manual-only — no idempotent auto-generated actions from quote/return/warranty deadlines. Not started this session. |
| MONEY | PASS | Real ledger + hero UI treatment this session. |
| MONEY_INTEGRITY | FAIL | No dedicated tests proving no double-counting across MADE/PROTECTED/RECOVERED/net; not audited this session. The UI derives totals from the same `money_events` rows web and mobile both already write to (one canonical ledger, not parallel computations), which is the right foundation, but that claim isn't backed by a test. |
| MAKE | PASS | Contacts/leads/opportunities/quotes verified via code review; Business subpages got their first real structural design pass this session. |
| PROTECT | PASS | Purchases/returns/warranties, both platforms as of this session (mobile Warranties added `81454cc`). |
| RECOVER | PASS | Items/valuations/listings/sales; Sell rebuilt as an image gallery this session. |
| WARRANTIES | PASS | Mobile added this session (`81454cc`), mirrors web control-for-control. |
| ITEM_PHOTO_UPLOAD_WEB | PASS | Built this session: private `item-photos` bucket, client upload + Server Action attach, signed-URL display, remove. `tsc`/`eslint`/`next build` clean. Not exercised against a live authenticated session (see AUTHENTICATED QA blocker). |
| ITEM_PHOTO_UPLOAD_ANDROID | PASS | Built this session: `image_picker` + `SellRepository.pickAndUploadPhoto`/`removePhoto`, same bucket/signed-URL pattern as web. `flutter analyze`/`test` clean, debug APK with the new plugin installs and launches cleanly on the real Galaxy A14. Not exercised end-to-end against a live authenticated session. |
| DOCUMENTS | PASS | Pre-existing `documents` table/bucket, unchanged this session. |
| STORAGE | PASS | `documents` (pre-existing) + `item-photos` (new this session) buckets, both private, both path-partitioned by `account_id`, both reuse `has_account_access()`. |
| AI_UI | PASS | "Ask LOOP" rebuild this session, both platforms — no robot/sparkle/gradient. |
| AI_BACKEND | OWNER_ACTION_REQUIRED | Engineering (tool registry, confirm/decline gate, `/api/ai/chat`+`/api/ai/confirm`) was already complete from an earlier session; not re-audited line-by-line this session beyond confirming it still builds. `ANTHROPIC_API_KEY` remains genuinely unset — cannot be live-verified without it. |
| DATABASE | PASS | 12 migrations now (3 added this session: `item_photos_storage`, `optimize_rls_auth_uid_initplan`, `index_unindexed_foreign_keys`), all applied to the real hosted project and tracked in `supabase/migrations/`. |
| MIGRATIONS | PASS | See above — hosted `list_migrations` and local `supabase/migrations/` confirmed to match after each apply this session. |
| RLS | PASS | Every table still has RLS enabled (spot-checked `businesses`/`business_members`/`profiles` after this session's policy rewrite). 5 policies' `auth.uid()` calls wrapped in `(select auth.uid())` for query-plan caching this session — semantics unchanged (same boolean expression, verified against `pg_policies` before and after), performance advisor's `auth_rls_initplan` warning now clear. |
| FUNCTION_SECURITY | PASS | `search_path`/anon-execute hardening from an earlier session unchanged; this session's 4 flagged `SECURITY DEFINER` helper functions (`has_account_access`, `is_active_business_member`, `is_business_admin`, `shares_active_business`) reviewed and confirmed intentional — narrow, ID-scoped access checks, not broad data exposure; `rls_auto_enable` is a Supabase-platform-owned event trigger, not app code. |
| WEB_TESTS | FAIL | No browser/component test runner exists yet — still build-time checks only (`lint`/`typecheck`/`build`). Not started this session; real, scoped follow-up work (section 28 of the continuation directive). |
| FLUTTER_TESTS | PASS | 5/5 passing, reverified after every change this session. Coverage is shallow (one widget-boot test, a redirect test, 2 money-formatting unit tests) — real but not comprehensive. |
| DATABASE_TESTS | NOT_RUN | pgTAP suite (20/20 per an earlier session) exists and `supabase-ci.yml` runs it on every push, but Docker Desktop isn't running in this environment so it couldn't be re-executed locally after this session's 3 new migrations. The new migrations are simple additive DDL (bucket+policy insert, policy replace with an equivalent expression, `create index if not exists`) with no plausible interaction with the existing pgTAP assertions, but that's reasoning, not a rerun — CI will be the first real confirmation on next push. |
| CI | PASS | Reviewed all 3 workflows this session (`.github/workflows/*.yml`): each runs real commands with no `continue-on-error`/skip — `mobile-ci` does `flutter pub get`+format+analyze+test, `web-ci` does lint+typecheck+build, `supabase-ci` does a full `supabase db reset` (replays every migration from empty) + `supabase test db`. Not modified this session; already correctly configured. |
| ACCESSIBILITY | IN_PROGRESS | Color contrast fully WCAG-computed (docs/DESIGN_SYSTEM.md). This session additionally found and fixed a real gap while building the new nav rail: several icon-only controls (nav items, wordmark link, account chip, sign-out) had no accessible name below the `lg` breakpoint — added explicit `aria-label`s. Not done: keyboard-nav walkthrough, focus-trap/Escape handling on menus/dialogs, full screen-reader pass, touch-target audit. |
| RESPONSIVE_WEB | IN_PROGRESS | Public pages (`/sign-in`, `/sign-up`) visually verified at 1522px and 390px this session, real browser, no overflow. Authenticated pages (the ones with the new nav rail, hero Money, gallery Sell) not verified at any width — blocked on the same auth-classifier constraint as ITEM_PHOTO_UPLOAD. |
| ANDROID_BUILD | PASS | `flutter build apk --debug` succeeded twice this session (once after the Murex Noir/Warranties changes, once after the photo-upload/image_picker changes) — real APK, not just static analysis. One environment quirk hit and resolved: a stale `build/app/intermediates/assets/debug/...` directory (OneDrive file-lock pattern, same class of issue as the documented `npm install` one) blocked the first attempt; `rm -rf build` (safe — gitignored) fixed it. |
| GALAXY_A14_CONNECTION | PASS | Wireless ADB reconnected this session — see the resolved entry in docs/KNOWN_ISSUES.md for the exact `adb connect`/`MSYS_NO_PATHCONV` fixes needed. |
| GALAXY_A14_VISUAL_QA | PARTIAL | One real screenshot confirmed (initial launch → sign-in screen renders correctly). Could not go further: any adb-driven interaction with the sign-in form was refused by the safety classifier (same guardrail as browser-automation credential entry) — genuinely blocked pending a human sign-in, not skipped. |
| GALAXY_A14_FUNCTIONAL_QA | PARTIAL | Install/launch/no-crash confirmed twice (logcat clear of FATAL EXCEPTION/Unhandled Exception both times, including after adding the `image_picker` native plugin). Every authenticated-screen functional check in the continuation directive's QA matrix (Today/Money/Sell/Business/Protect/AI/keyboard/back-gesture/dialogs) not reached — same blocker. |
| GALAXY_A14_PERFORMANCE | PARTIAL | No jank/crash/ANR observed through app launch; no cold/warm-launch timing or frame-rate measurement taken (would need an authenticated session to exercise the real screens, and no fabricated numbers per the directive's explicit instruction). |
| GALAXY_A14_LOGCAT | PASS | Cleared and inspected (`adb logcat -c`, then filtered for `FATAL EXCEPTION`/`AndroidRuntime`/`Unhandled Exception`) after each install this session — clean both times. |
| IOS_SOURCE_PARITY | IN_PROGRESS | Not fully audited. This session added the one concrete gap found while building item-photo upload: `NSPhotoLibraryUsageDescription` was missing from `Info.plist` (required for `image_picker`'s gallery source) — added. No broader Android-vs-iOS config diff performed. |
| IOS_REAL_BUILD | EXTERNAL_BLOCKER | Windows environment, no Xcode/macOS — unchanged, expected, not attempted. |
| SECURITY | PASS | Live advisor scan this session found and fixed the RLS-initplan performance issue (see RLS row); the remaining security advisor items (`rls_auto_enable`/4 helper functions callable by `authenticated`, `auth_leaked_password_protection` disabled) reviewed and are either intentional (helper functions — see FUNCTION_SECURITY) or a genuine one-click owner action (leaked-password protection is an Auth dashboard setting, not reachable via this session's SQL tools — see docs/KNOWN_ISSUES.md). |
| SECRET_SCAN | PASS | Grepped this session's diff + new files for API-key/token/private-key patterns — clean. |
| VERCEL | NOT_RUN | Not redeployed this session — no push to `origin/main` has happened yet in this continuation (see below); Vercel auto-deploys from `main` on push, so nothing to redeploy against yet. |
| PRODUCTION_WEB | NOT_RUN | Not reloaded/re-verified this session (same reason — nothing new pushed yet at the time of writing; will need a post-push check). |
| GITHUB | IN_PROGRESS | This session's work (item photo upload, Supabase RLS/perf hardening, doc updates) is committed locally but not yet pushed as of this row being written — see the commit immediately following this ledger update. |
| DOCUMENTATION | PASS | This file, KNOWN_ISSUES.md, and AUTONOMOUS_BUILD_STATUS.md all rewritten/updated this session to match live, verified reality. |
| EXTERNAL_BLOCKERS | — | See below. |

## LOOP_FINAL_STATE=NOT_READY

Not a failure — a real, honest snapshot, same discipline as the
directive itself demands. The single largest remaining body of work
(account identity: menu/profile/personalization/settings/help, on both
platforms) hasn't been started yet.

**Owner-only / external (cannot be done by an agent):**
- `ANTHROPIC_API_KEY` — AI chat cannot be live-verified without it.
- Leaked-password protection toggle (Supabase Auth dashboard setting).
- A live sign-in — either in a browser or on the physical Galaxy A14 —
  is the one thing standing between "built and statically verified"
  and "physically confirmed" for: item photo upload, the new nav
  rail/Money/Sell/Business/AI pages, and the rest of the Galaxy A14 QA
  matrix. This session's safety classifier correctly refuses to type a
  password into any field itself, on either surface; a human doing it
  once unblocks all of the above.
- iOS real build/TestFlight — needs macOS/Xcode.

**Genuine remaining engineering (not started or partially started, not
blocked on anything external):**
- Account identity: menu, profile, personalization, settings, help —
  entirely unbuilt on both platforms (sections 8–14 of the
  continuation directive).
- Today automation (idempotent action generation from real deadlines).
- Money integrity tests (prove no double-counting, not just "the UI
  reads from one ledger").
- Browser/component test coverage for `apps/web`.
- A broader iOS source-parity audit beyond the one gap found and fixed
  this session (photo-library usage description).
- `business_members`'s overlapping RLS policies (performance-only,
  deliberately deferred — see docs/KNOWN_ISSUES.md).
- Formal accessibility audit beyond contrast + the icon-only-nav
  accessible-name fix made this session.
- Formal responsive QA on authenticated pages at the full breakpoint
  set (360/390/430/768/1024/1280/1440+) — blocked on the same
  live-session constraint as physical QA, not on the app.

See docs/LOOP_CONTINUATION_PROMPT.md for the exact next-session
starting point.
