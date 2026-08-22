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
| ACCOUNT_IDENTITY | IN_PROGRESS | Built and **live-verified end-to-end on web** this session (`e92dd9e`): account menu, Profile, Settings, Personalization (a real System/Dark/Light theme, not a stub), Help. Mobile equivalent not started — same-shaped follow-up, real work, not blocked on anything. |
| ACCOUNT_MENU_WEB | PASS | `apps/web/src/components/account-menu.tsx`. **Live-verified**: opens/closes correctly, Escape closes and returns focus to the trigger, click-outside closes it, shows the real signed-in email and deterministic initials avatar (not a random color), all 6 items present and correctly routed (Switch account/Personalization/Profile/Settings/Help & Support/Sign out). No billing/plan rows — LOOP has no subscription tiers to justify them. |
| ACCOUNT_MENU_MOBILE | FAIL | Not started. |
| PROFILE | PASS | `apps/web/src/app/(app)/profile`. **Live-verified**: real avatar/name/email render correctly, the accounts/memberships list shows the real active account. The editable-display-name Server Action was code-reviewed (identical authenticated-client + RLS pattern already proven live by `attachItemPhoto`/`createItem`) but not submitted live — unlike the disposable test item, this would have written to the account owner's real identity data without being asked, which crosses into "explicit permission required" territory this session didn't have. No username field: `profiles` has `display_name` but no `username`, and LOOP has no public profiles/mentions/cross-account search that would make one earn its schema complexity — a real decision, not an oversight (see the commit message for the full reasoning). |
| PERSONALIZATION | PASS | `apps/web/src/app/(app)/settings/personalization`. **Live-verified all three states**: System (correctly matched the OS's dark preference), Light (clicked live — Royal Bone background, dark ink text, every page checked in this mode rendered correctly, not just the settings page itself), then reset back to System to leave the account as found. Real cookie-backed persistence (`apps/web/src/lib/theme.ts`), server-rendered `data-theme` so there's no flash of the wrong theme. |
| SETTINGS | PASS | `apps/web/src/app/(app)/settings`. **Live-verified**: only real sections shown (Account, Appearance, About) — no dead Notifications/Data-Privacy placeholders. |
| HELP | PASS | `apps/web/src/app/(app)/help`. **Live-verified**: real per-product-area guidance, and an honest line that Privacy Policy/Terms/a support inbox don't exist yet rather than dead links. |
| SIGN_OUT | PASS | Pre-existing, unchanged this session; visible and reachable in the live nav rail during this session's authenticated desktop QA (not clicked — no reason to end the session mid-QA). |
| ACCOUNT_SWITCHING | PASS | Pre-existing, RLS-enforced via `has_account_access()`. The "Personal" account chip rendered correctly in every live authenticated screenshot this session. |
| AUTH | PASS | Email/password real on both platforms; unchanged this session. |
| GOOGLE_AUTH_WEB | PASS | Verified live end-to-end in an earlier session (commit `07e5318`). Not re-attempted this session (no reason to sign out of the real authenticated session that became available — see AUTHENTICATED QA entry). |
| GOOGLE_AUTH_ANDROID | PASS | Verified on the real Galaxy A14 in an earlier session (`ab846c3`). Not re-attempted this session (same reasoning). |
| TODAY | PASS | Real actions queue. **Visually verified live this session** on real production data (`loop-teal-rho.vercel.app`, authenticated) — correct empty state, correct nav highlight, zero console errors. |
| TODAY_AUTOMATION | FAIL | Still manual-only — no idempotent auto-generated actions from quote/return/warranty deadlines. Not started this session. |
| MONEY | PASS | Real ledger + hero UI treatment this session. **Visually verified live**: the $0.00 Fraunces hero figure, MADE/PROTECTED/RECOVERED row, and the quieter Spent/Fees line all render exactly as designed against real (empty) account data. |
| MONEY_INTEGRITY | FAIL | No dedicated tests proving no double-counting across MADE/PROTECTED/RECOVERED/net; not audited this session. The UI derives totals from the same `money_events` rows web and mobile both already write to (one canonical ledger, not parallel computations), which is the right foundation, but that claim isn't backed by a test. |
| MAKE | PASS | Contacts/leads/opportunities/quotes verified via code review; Business subpages got their first real structural design pass this session. **Business hub and Contacts visually verified live** — account list, hub cards, and the Contacts form/empty-state all render correctly against real data. |
| PROTECT | PASS | Purchases/returns/warranties, both platforms as of this session (mobile Warranties added `81454cc`). **Purchases page visually verified live** — form, empty state, all correct. |
| RECOVER | PASS | Items/valuations/listings/sales; Sell rebuilt as an image gallery this session. **Fully verified live end-to-end**, not just visually — see ITEM_PHOTO_UPLOAD_WEB. |
| WARRANTIES | PASS | Mobile added this session (`81454cc`), mirrors web control-for-control. Not exercised live this session (no existing purchase to attach one to in the real account, and creating throwaway financial-looking test data felt like the wrong tradeoff vs. the item-photo test, which had a clean SQL cleanup path). |
| ITEM_PHOTO_UPLOAD_WEB | PASS | Built this session: private `item-photos` bucket, client upload + Server Action attach, signed-URL display, remove. **Verified live end-to-end on real production** — created a real test item, uploaded a real PNG, watched it round-trip through Storage and render correctly, found and fixed a real bug (no way to remove the hero/first photo, only additional ones — `3af51c2`), then removed the photo and deleted the test item, confirmed via SQL that nothing was left behind. |
| ITEM_PHOTO_UPLOAD_ANDROID | PASS | Built this session: `image_picker` + `SellRepository.pickAndUploadPhoto`/`removePhoto`, same bucket/signed-URL pattern as web (including the hero-photo-removal fix, applied to both platforms together). `flutter analyze`/`test` clean, debug APK installs and launches cleanly on the real Galaxy A14. Not exercised end-to-end on-device — same password-entry constraint as the rest of Galaxy A14 authenticated QA. |
| DOCUMENTS | PASS | Pre-existing `documents` table/bucket, unchanged this session. |
| STORAGE | PASS | `documents` (pre-existing) + `item-photos` (new this session) buckets, both private, both path-partitioned by `account_id`, both reuse `has_account_access()`. |
| AI_UI | PASS | "Ask LOOP" rebuild this session, both platforms — no robot/sparkle/gradient. **Visually verified live**: Fraunces heading, honest "not configured" state, correct nav icon (Loop Seal, not a sparkle). |
| AI_BACKEND | OWNER_ACTION_REQUIRED | Engineering (tool registry, confirm/decline gate, `/api/ai/chat`+`/api/ai/confirm`) was already complete from an earlier session; not re-audited line-by-line this session beyond confirming it still builds. `ANTHROPIC_API_KEY` remains genuinely unset — cannot be live-verified without it. |
| DATABASE | PASS | 12 migrations now (3 added this session: `item_photos_storage`, `optimize_rls_auth_uid_initplan`, `index_unindexed_foreign_keys`), all applied to the real hosted project and tracked in `supabase/migrations/`. |
| MIGRATIONS | PASS | See above — hosted `list_migrations` and local `supabase/migrations/` confirmed to match after each apply this session. |
| RLS | PASS | Every table still has RLS enabled (spot-checked `businesses`/`business_members`/`profiles` after this session's policy rewrite). 5 policies' `auth.uid()` calls wrapped in `(select auth.uid())` for query-plan caching this session — semantics unchanged (same boolean expression, verified against `pg_policies` before and after), performance advisor's `auth_rls_initplan` warning now clear. |
| FUNCTION_SECURITY | PASS | `search_path`/anon-execute hardening from an earlier session unchanged; this session's 4 flagged `SECURITY DEFINER` helper functions (`has_account_access`, `is_active_business_member`, `is_business_admin`, `shares_active_business`) reviewed and confirmed intentional — narrow, ID-scoped access checks, not broad data exposure; `rls_auto_enable` is a Supabase-platform-owned event trigger, not app code. |
| WEB_TESTS | FAIL | No browser/component test runner exists yet — still build-time checks only (`lint`/`typecheck`/`build`). Not started this session; real, scoped follow-up work (section 28 of the continuation directive). |
| FLUTTER_TESTS | PASS | 5/5 passing, reverified after every change this session. Coverage is shallow (one widget-boot test, a redirect test, 2 money-formatting unit tests) — real but not comprehensive. |
| DATABASE_TESTS | NOT_RUN | pgTAP suite (20/20 per an earlier session) exists and `supabase-ci.yml` runs it on every push, but Docker Desktop isn't running in this environment so it couldn't be re-executed locally after this session's 3 new migrations. The new migrations are simple additive DDL (bucket+policy insert, policy replace with an equivalent expression, `create index if not exists`) with no plausible interaction with the existing pgTAP assertions, but that's reasoning, not a rerun — CI will be the first real confirmation on next push. |
| CI | PASS | Reviewed all 3 workflows this session (`.github/workflows/*.yml`): each runs real commands with no `continue-on-error`/skip — `mobile-ci` does `flutter pub get`+format+analyze+test, `web-ci` does lint+typecheck+build, `supabase-ci` does a full `supabase db reset` (replays every migration from empty) + `supabase test db`. Not modified this session; already correctly configured. |
| ACCESSIBILITY | IN_PROGRESS | Color contrast fully WCAG-computed (docs/DESIGN_SYSTEM.md). This session found and fixed a real gap while building the nav rail: several icon-only controls had no accessible name below the `lg` breakpoint — added explicit `aria-label`s. The new account menu has real Escape/outside-click/focus-return handling, live-verified, not just coded (see ACCOUNT_MENU_WEB). Not done: a full keyboard-only walkthrough of every page, a screen-reader pass, and a touch-target audit. |
| RESPONSIVE_WEB | IN_PROGRESS | Public pages (`/sign-in`, `/sign-up`) visually verified at 1522px and 390px this session, real browser, no overflow. Authenticated pages verified live at desktop width (Today/Money/Sell/Business/Contacts/AI, all correct, zero console errors). Mobile-width verification of the *authenticated* app attempted twice this session (resizing an existing tab, and pre-sizing a fresh tab before navigating) — both times the browser tool's `resize_window` reported success but the rendered viewport stayed desktop-sized; reads as a genuine tool limitation specific to this app shell (the public sign-in page resized correctly earlier in the same session), not something fixable in the app. |
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
| VERCEL | PASS | Every push this session auto-deployed and reached `READY` on `production` (confirmed via `list_deployments`/`get_deployment`) — `3c2a911` then `3af51c2`, both green, both correctly aliased to `loop-teal-rho.vercel.app`. |
| PRODUCTION_WEB | PASS | Live-verified this session, authenticated, real browser: Today/Money/Sell/Business/Contacts/AI all correct, zero console errors, and a real create→upload→remove→delete round trip completed successfully against the live production Storage bucket and database. |
| GITHUB | PASS | All of this session's work pushed to `origin/main`, fast-forward only, verified via `git ls-remote` after each push (`5858424`→`c5ecd1e`→`1fe3aef`→`81454cc`→`3c2a911`→`3af51c2`→`0974f13`→`e92dd9e`). |
| DOCUMENTATION | PASS | This file, KNOWN_ISSUES.md, and AUTONOMOUS_BUILD_STATUS.md all rewritten/updated this session to match live, verified reality. |
| EXTERNAL_BLOCKERS | — | See below. |

## LOOP_FINAL_STATE=NOT_READY

Not a failure — a real, honest snapshot, same discipline as the
directive itself demands. Web's account identity (menu/profile/
personalization/settings/help) is now built and live-verified; the
same surface still needs building on mobile, and a handful of other
real, scoped items remain below.

**Owner-only / external (cannot be done by an agent):**
- `ANTHROPIC_API_KEY` — AI chat cannot be live-verified without it.
- Leaked-password protection toggle (Supabase Auth dashboard setting).
- A live sign-in on the physical Galaxy A14 — the desktop-web half of
  this blocker resolved itself this session (an already-authenticated
  browser tab was available, not anything this session signed into —
  see docs/KNOWN_ISSUES.md), which is what unblocked the full desktop
  QA pass above. The mobile app's authenticated screens remain
  unreached: this session's safety classifier correctly refuses to
  type a password into any field itself, on-device or in-browser, so
  a human doing it once on the physical device is what's left.
- iOS real build/TestFlight — needs macOS/Xcode.

**Genuine remaining engineering (not started or partially started, not
blocked on anything external):**
- Account identity on mobile — web is done and live-verified (menu,
  Profile, Settings, Personalization, Help); Flutter needs the same
  surface (a bottom-sheet/panel equivalent of the menu, since mobile's
  `RootShell` currently has no account-identity entry point at all).
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
  set (360/390/430/768/1024/1280/1440+) — desktop width now verified
  live; narrower widths blocked on a `resize_window` tool limitation
  this session hit twice (see docs/KNOWN_ISSUES.md), not on the app or
  on a missing session.

See docs/LOOP_CONTINUATION_PROMPT.md for the exact next-session
starting point.
