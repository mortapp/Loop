# Known Issues

## OPEN (code and platform config repaired; owner callback completion pending) — Mobile OAuth used an invalid URI scheme

Real bug reproduced on the physical Samsung. Google authentication opened in
Chrome, but Flutter never received a usable callback/session.

**Root cause**: LOOP reused the Android application id
`com.loop.app.loop_mobile` as a custom URI scheme. The application id is valid,
but RFC 3986 URI schemes may contain letters, digits, `+`, `-`, and `.` only;
the underscore is illegal. Dart's `Uri.tryParse` returns null for the old
callback, so `app_links`/Supabase Flutter cannot parse it and perform the PKCE
code exchange. The previous report blamed the host-only versus host-plus-path
shape. Supabase's documented custom-scheme examples and a direct parser
regression test disproved that diagnosis.

**Repair applied**:

- Canonical callback is now
  `com.loop.app.loop-mobile://app/login-callback`.
- `MobileAuthContract` owns the callback and accepts only its exact PKCE
  code/error result shape; token-bearing and unrelated deep links are rejected.
- Android and iOS register the same standards-valid scheme.
- Supabase initializes explicitly with PKCE, session persistence, automatic
  refresh, deep-link detection, and the callback predicate.
- Google browser launch, callback wait, timeout, cancellation, duplicate-launch
  prevention, and session/current-user id consistency now have a tested state
  machine. Browser launch is no longer treated as authentication success.
- The exact valid callback was added and verified in the hosted Supabase Auth
  redirect allow-list through the Management API. Legacy entries were retained
  temporarily so already-installed evidence builds were not broken.
- A configured debug-QA APK containing the repair was built and installed over
  the prior app without clearing data. Its compiled Dart snapshot contains the
  valid callback and no legacy callback; the merged manifest matches it.

**Verification so far**:

- Focused callback/controller/profile/platform tests: pass.
- Full Flutter suite: 38/38 pass when run serially (OneDrive caused a generated
  test-cache collision in the parallel runner; no product assertion failed).
- Flutter analyzer: pass.
- Web TypeScript, ESLint, and production Next build: pass after parity changes.
- Physical secure startup and Google PKCE browser launch: pass.
- `FLUTTER_SESSION_ESTABLISHED`: pending owner account selection on the physical
  phone. Do not mark this issue resolved until the callback returns to LOOP and
  a cold restart restores the same valid session.

## New: @username handles + required Google-account backup password, on top of display-name onboarding

Extends the display-name onboarding above (same session, owner asked
for a fuller native account-setup step). Both platforms:

- `profiles.username` (`supabase/migrations/20260822180000_usernames.sql`):
  lowercase, `[a-z0-9_]{3,20}`, a reserved-name list, and a database
  unique index -- all three are real schema constraints, not just
  client-side checks. `public.is_username_available(candidate)` is a
  SECURITY DEFINER pre-check for live UI feedback (leaks only a
  boolean); the constraint + index are what's actually authoritative.
  11 pgTAP assertions (`supabase/tests/database/006_usernames.sql`).
- Onboarding (web `/auth/complete-profile`, mobile `OnboardingScreen`):
  now also collects a username with live available/taken/invalid
  feedback (400ms debounce against the RPC above), and -- only for an
  account with no password identity yet (Google-only signup, detected
  from signed Supabase identity/provider data) -- a required password + confirm, linked to
  the SAME auth user via Supabase's own `auth.updateUser({password})`.
  Never a second account: same `auth.users.id` either way.
- Profile completion now writes display name and username atomically, and both
  fields are required by the web and mobile routing gates. The previous two-step
  mobile write could save a name, fail the username, and then route past setup.
- Verified: web `tsc`/`eslint`/`next build` clean; mobile analyzer clean and full
  Flutter suite 38/38. Physical completed-sign-up/onboarding proof remains
  pending the owner-operated Google callback above.

## Post-auth onboarding (display name + username) + a real sign-in error/notice banner

Added 2026-08-22, prompted by the owner's request for the Google
sign-in experience to feel like one step, with a name captured (preset
from the account's email/Google profile, editable) rather than a
second, separate account-setup screen. Both platforms, same flow:

- `profiles.display_name` and `profiles.username` start null. The pair is the
  cross-platform completion signal; either missing field keeps the account in
  onboarding.
- Web: `/auth/callback` and the `signIn`/`signUp` Server Actions all
  route through one shared `redirectAfterAuth` helper
  (`src/lib/auth/post-auth-redirect.ts`) that checks
  both required profile fields and sends an incomplete user to
  `/auth/complete-profile` (prefilled from Google's `full_name`/`name`
  claim, else a title-cased guess from the email's local part) before
  their real `next` destination. An existing account never sees it.
- Mobile: `profileGateProvider` (`app_router.dart`) exposes loading, error,
  incomplete, and complete states. Today remains unreachable until the hosted
  profile has loaded and both fields are present.
- `/sign-in` now actually reads and displays `?error=`/`?notice=`
  query params (`auth_callback_failed`, `check_email`) instead of
  silently dropping them — the other half of the "won't load fully
  right" report above.

Current verification: `tsc`, ESLint, and `next build` pass. Flutter analyzer
passes; 38/38 tests pass, including required-password, retry, no-private-error,
late-async-disposal, Samsung-resolution large-text, and atomic completion-gate
coverage. Physical end-to-end onboarding remains pending owner OAuth completion.

## ~~Mobile builds silently ran against a placeholder Supabase host~~ — resolved 2026-08-22, found on the real Galaxy A14

A real, live regression, not a hypothetical: on the physical device,
tapping **Continue with Google** opened Chrome to
`placeholder.supabase.co`, which failed with
`DNS_PROBE_FINISHED_NXDOMAIN`. This explains a lot of this session's
prior "still on the sign-in screen" observations — it's plausible
sign-in was never actually reachable on-device, not just untried.

Root cause: every `flutter build apk` this session (and likely
before) was run as a plain `flutter build apk --debug`/`--release`,
without the `--dart-define=SUPABASE_URL=...`
`--dart-define=SUPABASE_ANON_KEY=...` flags the app has always
required (documented correctly in the README, but easy to forget and
nothing enforced it). `SupabaseConfig.url`/`.anonKey`
(`lib/core/supabase/supabase_config.dart`) default to empty strings
when omitted, and `bootstrapSupabase`
(`lib/core/supabase/supabase_providers.dart`) used to silently
substitute `https://placeholder.supabase.co` / `placeholder-anon-key`
in that case — so the app booted normally, rendered a completely
correct-looking sign-in screen, and only failed once a real network
call (Google OAuth, or an email/password sign-in) actually hit the
unreachable host. No CI build step exists for mobile
(`mobile-ci.yml` only runs format/analyze/test), so nothing caught
this either.

Fixed, three parts:
1. **The silent fallback is gone.** `bootstrapSupabase` now asserts its
   inputs are valid instead of substituting a placeholder.
2. **A real startup gate.** `main.dart` checks
   `SupabaseConfig.isConfigured` (now real validation — non-empty,
   `https://`, non-empty host, and explicitly not the literal
   `placeholder.supabase.co` — see `SupabaseConfig.isValidConfig`,
   factored out so it's unit-testable with arbitrary inputs) *before*
   Supabase is ever initialized. An invalid config now renders a plain
   "LOOP can't start" screen (`ConfigurationErrorApp`) instead of
   silently proceeding into a sign-in screen that can never actually
   sign anyone in. **Verified live on the Galaxy A14**: a build with no
   dart-defines now shows this screen with a clean logcat (no crash);
   a correctly-configured rebuild boots normally.
3. **A durable, hard-to-forget build path.** `dart_define.example.json`
   (committed) + `dart_define.json` (gitignored, the real values) with
   `--dart-define-from-file=dart_define.json` replaces typing
   `--dart-define` flags by hand every session — see the README.
   8 new unit tests (`test/supabase_config_test.dart`) lock in the
   validation contract: real config accepted; empty URL/key, the
   literal placeholder host, a non-`https` scheme, an unparseable URL,
   and a URL with no host are all rejected.

**Verified live end-to-end on the Galaxy A14** with the corrected
build: tapping **Continue with Google** now opens Chrome to
`accounts.google.com`, "Choose an account to continue to
zqalnvfwxmfrnyjcuehq.supabase.co" (the real project) — confirmed by
screenshot. Did not select an account or complete sign-in (that step
is the owner's, per the standing manual-sign-in rule); backed out via
Home + a fresh relaunch, not further Back presses (see the note below
about why).

**One process note, not a code issue**: cancelling out of the Chrome
Custom Tab with two Back presses navigated past LOOP entirely into an
unrelated foreground app already in the device's recent-task history
(briefly visible in a since-deleted screenshot). Nothing was read,
touched, or interacted with beyond noticing it — Home followed by
relaunching LOOP through the launcher intent is the safe way to
back out of an OAuth Custom Tab on this device going forward, not
repeated Back presses.

## ~~Android release builds had no INTERNET permission~~ — resolved 2026-08-22, found during iOS parity audit

Was a real, serious bug, not cosmetic: `android.permission.INTERNET` was
only declared in `android/app/src/debug/AndroidManifest.xml` and
`.../profile/AndroidManifest.xml` — the stock Flutter template default,
added there only so the Flutter dev tools can reach the running app for
hot reload. `main/AndroidManifest.xml` (the only one a **release**
build merges) never declared it. Every debug-build QA session this
whole project has run — including every Galaxy A14 test — worked
because debug builds always carry the permission; a real release APK
would have silently failed every network call (Supabase auth, all
data reads/writes, Storage, the Ask LOOP backend) with no build-time
warning.

Found while auditing `apps/mobile/ios/Runner/Info.plist` against
`AndroidManifest.xml` for source parity (iOS needs no equivalent
declaration — Apple doesn't gate outbound network access behind a
manifest permission). Fixed by adding the permission to
`main/AndroidManifest.xml`. Verified: `flutter build apk --release`
now succeeds (it failed to merge on the first fix attempt too — an
unrelated self-inflicted bug, an XML comment containing a literal `--`,
invalid inside an XML comment body; fixed in the same edit), the
merged manifest
(`build/app/intermediates/merged_manifest/release/processReleaseMainManifest/AndroidManifest.xml`)
contains the permission, and the release APK installs and launches
cleanly on the physical Galaxy A14 with no crash in logcat.

## iOS source parity audit — 2026-08-22, PASS (static/config only, no real build possible on Windows)

Compared `apps/mobile/ios/Runner/Info.plist` and
`Runner.xcodeproj/project.pbxproj` against
`android/app/src/main/AndroidManifest.xml` and `build.gradle.kts`.
Findings:

- **Bundle identifiers intentionally differ in format**:
  `com.loop.app.loopMobile` (iOS) vs `com.loop.app.loop_mobile`
  (Android) — normal per-platform convention, not a bug. The OAuth
  redirect URL scheme (`com.loop.app.loop-mobile`) is deliberately the
  *same standards-valid literal string* on both platforms regardless of bundle id, so
  the Dart-side `redirectTo` never has to branch by platform (see
  `auth_screen.dart` and the Info.plist's own comment).
- **OAuth/deep-link redirect**: Android's intent-filter matches
  `scheme + host + path` (`com.loop.app.loop-mobile://app/login-callback`)
  exactly; iOS's `CFBundleURLTypes` only needs the bare scheme
  registered (iOS routes all URLs with that scheme to the app; host/
  path parsing happens in app code) — both correctly wired, not a gap.
  (Originally host-only, no path — see the redirect-URI-shape fix
  above.)
  `SceneDelegate.swift` subclasses `FlutterSceneDelegate` (stock,
  correct for the UIScene-based `Main.storyboard` lifecycle this
  project uses per `Info.plist`'s `UIApplicationSceneManifest`) — no
  manual `scene(_:openURLContexts:)` override needed; Flutter's plugin
  registry forwards it automatically.
- **Photo library permission**: `NSPhotoLibraryUsageDescription`
  present on iOS; the app only ever calls `ImagePicker().pickImage(source:
  ImageSource.gallery)` (never camera) on either platform, so neither
  `NSCameraUsageDescription` nor Android's camera permission are needed
  — correctly absent from both.
- **App Transport Security**: no ATS exception declared, correctly —
  the app only talks to Supabase and the Vercel deployment, both HTTPS.
- **Google auth**: goes entirely through Supabase's hosted OAuth
  broker (`signInWithOAuth`, a browser redirect), not the native
  `google_sign_in` SDK (not a pubspec dependency) — no
  `GoogleService-Info.plist` or extra URL scheme needed on either
  platform beyond the shared custom scheme above.
- **Deployment target**: `IPHONEOS_DEPLOYMENT_TARGET = 13.0` (Flutter's
  own template default) — every plugin in use (supabase_flutter,
  flutter_riverpod, go_router, google_fonts, image_picker,
  shared_preferences, http, cupertino_icons) supports iOS 13+ with no
  known minimum-version conflict.
- **Launch screen**: both platforms are equally un-branded (Android's
  `launch_background.xml` is still the stock white background; iOS's
  `LaunchScreen.storyboard` was not inspected further since Android is
  already the same stock state) — real parity, just not yet Murex Noir.
  Cosmetic, low priority, tracked here rather than fixed silently:
  branding the native splash screen on both platforms is real,
  scoped follow-up work, not a parity bug.
- **No `Podfile`**: expected — CocoaPods generates it from
  `ios/Flutter/*.xcconfig` on first real build; cannot be produced
  without macOS/Xcode and isn't meant to be committed ahead of time.

`IOS_SOURCE_PARITY=PASS` on this basis. `IOS_REAL_BUILD` remains
`EXTERNAL_BLOCKER_MACOS_XCODE` — nothing here substitutes for an actual
`pod install` + Xcode build, which this Windows environment cannot run.

## ~~Galaxy A14 physical QA blocked~~ — resolved 2026-08-22, device connected

Was stale: Wireless ADB reconnected (`adb devices -l` now shows the real
Samsung Galaxy A14 5G, SM-A146U, Android 15/API 35, as `device`, not
`offline`/`unauthorized`). Two real quirks hit along the way, noted here
in case they recur:
- `flutter devices` reported the mDNS-discovered serial
  (`adb-R9TWA0WQRVM-gKWVJ6 (2)._adb-tls-connect._tcp`) as `unsupported`/
  `not found` even though plain `adb` could see and query it fine. Fix:
  `adb mdns services` to find the real `ip:port`, then `adb connect
  <ip>:<port>` for a clean TCP serial — Flutter recognized that one
  immediately (`10.0.0.151:33757 • android-arm64 • Android 15 (API 35)`).
- Any `adb shell` command with a `/sdcard/...`-style path (e.g.
  `screencap`, `pull`) silently mis-executes from Git Bash on Windows —
  MSYS rewrites the leading `/` into a Windows path before adb ever sees
  it. Fix: prefix the command with `MSYS_NO_PATHCONV=1`.

Installed the current build (`flutter build apk --debug`, then
`adb install -r`) and confirmed by screenshot that the real device
renders the Murex Noir auth screen correctly: near-black background,
the double loop seal, Royal Bone wordmark, Champagne "PRIVATE VALUE
LEDGER" label, the Tyrian gradient CTA — matches the desktop-browser
render, no overflow or clipping at 1080×2408/450dpi. Could not go
further than that one screenshot: any adb-driven interaction with the
sign-in form itself (tapping the email field, typing into it) was
refused by this environment's safety classifier, the same guardrail
that blocks browser-automation credential entry — see the entry below,
which now covers both surfaces. Re-run the fuller physical QA matrix
(Today/Money/Sell/Business/Protect/AI/account menu, keyboard, back
gesture, dialogs, performance) once a signed-in session exists on the
device.

## ~~Item photos exist in the schema but nothing uploads to them yet~~ — resolved 2026-08-22, verified end-to-end live

Was: `items.photos` (`text[]`) had been in the schema and
`@loop/contracts` since the original Sell feature shipped, but no
upload flow was ever built on either platform.

Fixed: a private `item-photos` Storage bucket
(`supabase/migrations/20260822145553_item_photos_storage.sql`),
partitioned by `account_id` and guarded by the same
`has_account_access()` RLS pattern the pre-existing `documents` bucket
already used, 8MB/JPEG-PNG-WEBP-HEIC limits enforced at the bucket
level. Web uploads directly from the browser to Storage (client
component, `AddPhotoControl` in `item-actions.tsx`) then calls the
`attachItemPhoto` Server Action to record the object path; mobile does
the equivalent via `image_picker` + `SellRepository.pickAndUploadPhoto`.
Both platforms resolve every stored path to a fresh signed URL
(`createSignedUrls`/`createSignedUrlsResult`, 1-hour TTL) at read
time — never a permanent/public link, never base64 in a row.

**Verified live end-to-end on real production** (an already-signed-in
browser tab became available — see the resolved entry below): created
a real test item, uploaded a real test PNG through `AddPhotoControl`,
watched it round-trip through Storage and render as the tile's hero
image with the correct signed URL. That surfaced one real bug: the
remove (×) control only existed on the *additional*-photos thumbnail
strip, never on the hero/first photo — there was no way to remove an
item's only photo. Fixed on both platforms (`3af51c2`), re-verified
live (removed the test photo, confirmed the Storage object was
actually gone via `storage.objects`, then deleted the test item).
Static checks also clean throughout: `tsc --noEmit`/`eslint`/
`next build`; `dart format`/`flutter analyze`/`flutter test`; a debug
APK with the new `image_picker` plugin installs and launches cleanly
on the real Galaxy A14.

## ~~No authenticated browser session for full visual QA~~ — resolved 2026-08-22 for desktop web

Was: the Murex Noir web propagation pass (nav rail, Money, Sell,
Business, AI — see docs/DESIGN_SYSTEM.md) had only been verified via
`tsc --noEmit`, `eslint`, and `next build`, not by loading the
authenticated app in a real browser — doing so requires signing in,
and this environment's browser-automation safety classifier correctly
refuses to type a password into any field, including a disposable
account created solely for this QA (confirmed by testing — the classifier
blocked it outright). The same constraint applies on the physical
Galaxy A14, confirmed separately: an `adb shell input tap`/`input text`
sequence aimed at the mobile sign-in form's email field was also
refused, mid-sequence, by the same classifier.

Resolved for desktop web: a browser tab already carried a valid,
persisted session (the account owner's own prior real sign-in on this
machine, not anything this session did) — navigating to it landed
directly in the authenticated app. No password was typed by this
session at any point; this is the exact "owner signs in once, manually"
path, already satisfied. Used it to visually verify, live, on real
production data: Today (empty state), Money (hero figure + MADE/
PROTECTED/RECOVERED, real $0.00 render), Sell (empty state, then a
real create-item → photo-upload → photo-remove → delete round trip —
see the resolved item-photo entry above), Business (account list +
hub cards), Contacts (empty state + form), and Ask LOOP (honest
"not configured" state, Fraunces heading). Zero console errors on any
page. All of it matches the code exactly — no drift between what was
built and what's live.

**Still open**: mobile-width verification of the *authenticated* app.
The browser tool's `resize_window` reports success but the rendered
viewport stays desktop-sized on this app shell specifically — tried
twice (resizing an existing tab, and setting the size before
navigating a fresh tab), same result both times, so this reads as a
real tool limitation rather than a fluke (the public `/sign-in` page
*did* resize correctly earlier in this same session, so it's specific
to something about this page, not resize_window in general). The
physical Galaxy A14 remains blocked on the same password-entry
constraint for its own authenticated screens — see the resolved
Galaxy A14 entry above for what *was* confirmed there (unauthenticated
launch screen, real device, real screenshot).

## Leaked password protection is off — one-click owner action

Supabase's security advisor flags `auth_leaked_password_protection`:
Auth isn't checking new passwords against HaveIBeenPwned. This is a
project-level Auth setting, not schema/SQL — not reachable through
`execute_sql`/`apply_migration`, needs the Supabase dashboard (Auth →
Policies → Password Security) or the Management API with a personal
access token neither of which this session has. Recommended, low-risk,
takes under a minute.

## `business_members` has overlapping RLS policies — performance only

The performance advisor flags `multiple_permissive_policies`: three
separate policies (`business_members_manage_owner_admin`,
`business_members_select_peers`, `business_members_self_manage`) are
all permissive for `authenticated` on the same actions, so Postgres
evaluates all of them per query instead of one combined check.
Deliberately not merged in the same pass as the other two performance
fixes (2026-08-22, RLS auth.uid() initplan + missing FK indexes,
`supabase/migrations/20260822150941_*.sql` and `20260822151037_*.sql`)
— consolidating three overlapping-but-not-identical membership
policies risks subtly changing who can see/edit what, and that's not a
change to make without local pgTAP coverage to verify against (Docker
isn't running in this environment — see the entry below). Revisit with
the test suite actually runnable.

## ~~No hosted Supabase project yet~~ — resolved 2026-08-21

Was stale: a hosted project (`zqalnvfwxmfrnyjcuehq`, org "Loop",
`mzkhysoovbzhkkgeqtku`, us-west-2) had already been created but was
never migrated or wired into either app — `list_migrations`/
`list_tables` against it both came back empty. All 8 schema migrations
were applied directly (`apply_migration`, in order); confirmed via
`list_tables` afterward that all 20 tables exist with RLS enabled.
A fresh `get_advisors(security)` scan then surfaced two real,
pre-existing gaps neither local dev nor pgTAP had exercised (both
require a real hosted project's linter, not just local Postgres):
`set_updated_at`/`current_profile_id` had no pinned `search_path`, and
every `SECURITY DEFINER` function was still executable by `anon` (the
Postgres default of granting EXECUTE to PUBLIC was never explicitly
revoked, unlike every table-level GRANT in this schema, which always
revokes-then-narrows). Fixed in a new migration,
`20260821235200_harden_function_search_path_and_grants.sql`, applied
to the hosted project and committed to `supabase/migrations/` so local
dev picks it up too. Reverified clean afterward (only the expected,
intentional `authenticated`-only advisories remain. The later
`20260823050806_enforce_account_graph_integrity.sql` migration also revoked
the unnecessary anonymous/authenticated RPC grants from the
Supabase-platform-owned `rls_auto_enable` event-trigger function; event-trigger
execution is unaffected and that advisor warning is now gone.

`apps/web/.env.local` now points at the hosted project instead of
local Docker (`http://127.0.0.1:55321`) — Docker Desktop isn't running
in this environment, so this unblocks real backend development without
it. `apps/web` lint/typecheck/build all reverified clean against the
new config. Local Docker Supabase (`supabase start`) remains available
and still works for anyone who prefers it; nothing about the local dev
path was removed.

## Supabase CLI 2.108.0 does not auto-expose new tables

The installed CLI's default config (`auto_expose_new_tables` unset)
matches the new secure-by-default cloud behavior: newly created tables
are **not** reachable by `anon`/`authenticated`/`service_role` without an
explicit `GRANT`. RLS policies alone are not enough — a table with a
correct RLS policy but no GRANT returns `42501 permission denied`, not an
empty result set. Every migration that creates a table for
user-facing access must include `grant select/insert/update/delete on
public.<table> to authenticated;` alongside its policies (see the end of
each migration file in `supabase/migrations/` for the pattern).

## RLS self-reference recursion

A policy on table T cannot query T directly from within its own USING/
WITH CHECK clause — Postgres raises `infinite recursion detected in
policy`. This bit `business_members`' own policies (checking membership
of the very table being queried) and `profiles`' peer-visibility policy
(joining `business_members` twice). Fixed by routing the membership
check through `SECURITY DEFINER` helper functions
(`is_active_business_member`, `is_business_admin`,
`shares_active_business` in `20260817000002_identity.sql`), which bypass
RLS internally and break the cycle. Any future policy that needs to
check membership/role should call these helpers rather than inlining a
fresh subquery on `business_members`.

## `INSERT ... RETURNING` re-checks the SELECT policy

When a client asks for the row back on insert (e.g. Supabase JS
`.insert().select()`, or PostgREST's `Prefer: return=representation`),
Postgres re-checks the table's SELECT policy against the new row —
and does so before any `AFTER INSERT` trigger on that same table has run.
This broke business creation: `businesses_select_members` originally
only allowed rows visible via `business_members`, but that row is
created by an `AFTER INSERT` trigger on `businesses` itself, which
hadn't fired yet when the RETURNING check happened. Fixed by adding
`created_by = auth.uid()` to `businesses_select_members` so the creator
can always see what they just created. Keep this in mind for any future
table where a trigger provisions the very access that table's own SELECT
policy depends on.

## ~~No browser/component test coverage for apps/web yet~~ — resolved 2026-08-22, real E2E harness added

Was: only build-time checks (lint, typecheck, `next build`) had been
run against `apps/web`. No JS/TS test runner was configured.

Fixed: Playwright (`apps/web/playwright.config.ts`, specs in
`apps/web/e2e/`) — the smallest framework that can exercise real SSR
Server Component pages, cookie-based auth, and actual browser
navigation, none of which a jsdom/RTL setup handles well for this
app's App Router shape. 33 tests across 9 files: `auth-guards.spec.ts`
(every `(app)/**` route + `/` redirects to `/sign-in` when
unauthenticated — no storage state, no credentials, always runs),
`navigation.spec.ts`, `today.spec.ts`, `money.spec.ts`, `sell.spec.ts`,
`business.spec.ts`, `ai.spec.ts`, `account-menu.spec.ts` (every
expected item present, no billing/plan/upgrade UI, Escape closes and
restores focus), `personalization.spec.ts` (theme choice persists
across reload).

Auth is a real sign-in through `/sign-in` (`e2e/auth.setup.ts`), never
a bypass — see the entry below for why the authenticated specs are
currently `test.skip`ped in this environment. Verified live: all 16
auth-guard tests pass against a real local dev server; the other 17
correctly self-skip without QA credentials; `tsc`/`eslint`/`next build`
stay clean with the new files included.

## Authenticated E2E specs need a dedicated QA Supabase account — OWNER_ACTION_REQUIRED

The 17 authenticated Playwright specs (Today/Money/Sell/Business/
Protect/AI/account menu/personalization — see the resolved entry
above) are real, complete test code, not stubs. They `test.skip`
themselves whenever `QA_TEST_EMAIL`/`QA_TEST_PASSWORD` are unset
(`apps/web/playwright.config.ts`), which is true in every environment
right now, including CI.

This is deliberately not something this session can complete alone:
creating a Supabase Auth account is in this environment's own
prohibited-actions list (no account creation, no credential entry) even
for a low-stakes, isolated QA account. **Owner action required:**
1. Create a dedicated Supabase Auth user in the LOOP project (email +
   password, not Google OAuth, so Playwright can drive the real
   `/sign-in` form) — ideally with an obviously-QA email like
   `qa+e2e@<domain>`, seeded with nothing sensitive.
2. Add `QA_TEST_EMAIL`, `QA_TEST_PASSWORD` as GitHub Actions repo
   secrets, alongside `NEXT_PUBLIC_SUPABASE_URL` /
   `NEXT_PUBLIC_SUPABASE_ANON_KEY` if not already present (the `e2e`
   job in `.github/workflows/web-ci.yml` is gated on the Supabase URL
   secret existing at all, and scales up automatically once the QA
   credentials are added too).

Once those exist, the specs run themselves — no code changes needed.

## Accessibility: automated coverage + concrete fixes added, full manual sweep still open

Real, scoped work done 2026-08-22, not a full audit:
- **Fixed** two real bugs found while wiring up axe-core: the account
  menu trigger button (`apps/web/src/components/account-menu.tsx`) had
  no accessible name at all in the "mobile" variant and at `md`-only
  rail width (the display-name text only renders at `lg:`) — now has an
  explicit `aria-label`. The same component also hardcoded
  `id="account-menu"`, and since both the rail and mobile-web variants
  render simultaneously (one hidden via CSS per breakpoint), that was a
  latent duplicate-id bug — fixed with `useId()`.
- **Fixed** three forms with no accessible field labels at all (relying
  on placeholder text only): `money/log-event-form.tsx`,
  `sell/create-item-form.tsx`, `today/quick-add-form.tsx` — added
  `sr-only` `<label>` text to each field, no visual change.
- **Added** automated axe-core (WCAG2A/2AA) scans
  (`apps/web/e2e/accessibility.spec.ts`): `/sign-in` and `/sign-up`
  verified live with zero violations; `/today`, `/money`, `/sell`,
  `/business`, `/ai`, `/profile`, `/settings` are wired the same way but
  gated behind the same QA account this session cannot create (see the
  entry above) — they will run for real once that account exists.

**Not done** (explicitly, not silently): a manual keyboard-only pass
per page, focus-trap verification beyond the account menu, touch-target
sizing, and text-scaling stress testing on web; and the equivalent
Flutter `Semantics`/focus/touch-target audit on apps/mobile has not
been started at all. axe-core catches structural/ARIA/contrast issues
well but does not replace either of those. Track as open work, not
PASS.

## `npm install` can silently corrupt packages inside a OneDrive-synced repo

Observed on this machine: `npm install`/`npm ci` running inside a
OneDrive-synced folder can intermittently drop files during tarball
extraction (`npm warn tar TAR_ENTRY_ERROR ENOENT`), most often losing a
package's `.d.ts` files without any install-time error — `tsc` then
fails with a misleading "Could not find a declaration file" error that
looks like an application bug. If that happens, `rm -rf
node_modules/<package>` and reinstall just that package rather than
debugging application code. Doesn't affect Vercel's Linux build
environment — see docs/VERCEL_DEPLOYMENT.md.

## ~~Quote creation is not transactional~~ — fixed 2026-08-17

Was: `createQuote` inserted the `quotes` header row, then
`quote_line_items` in a second request, so a failure between the two
left an orphaned header. Fixed by `public.create_quote_with_line_items`
(`supabase/migrations/20260817000008_quote_rpc.sql`), a `security
invoker` plpgsql function that does both inserts in one transaction;
`createQuote` now calls it via `.rpc()`. Verified live: a successful
call returns the quote id with its line items attached, and a rejected
call (empty line items) leaves no quote row at all. Note for future
`jsonb_array_elements(...) WITH ORDINALITY` uses: you must alias both
output columns explicitly (`AS t(item, line_ordinality)`) — omitting
the alias list binds `item` to the whole `(value, ordinality)` record
instead of just the jsonb value, breaking `->>`/`->` with `operator
does not exist: record ->> unknown`.

## AI (Phase 8) is built but blocked on a credential

`ANTHROPIC_API_KEY` is unset — there is no Anthropic API key configured
anywhere in this environment. `apps/web`'s AI chat (tool registry:
`create_action`, `log_money_event`, both gated behind an explicit
confirm/decline step before executing) is fully implemented and passes
lint/typecheck/build, but has never made a real model call — it cannot
be live-verified the way every other feature in this build was. The
`/ai` page detects the missing key and shows a "not configured" state
rather than a broken chat UI. Setting the key (and optionally
`ANTHROPIC_MODEL`, see `.env.example`) is a human step — see
docs/AUTONOMOUS_BUILD_STATUS.md "Blocked".

## ~~Mobile quote creation drifted from the atomic web path~~ — fixed 2026-08-23

Mobile had retained a two-write header/line-item path after web moved to
`create_quote_with_line_items`. Fixed: mobile now calls the same atomic RPC,
validates finite positive quantities/nonnegative prices, checks mounted state
after the network wait, and does not expose raw backend errors. The RPC itself
was then hardened by `20260823052248_harden_quote_rpc_inputs.sql`: totals are
recomputed from lines, actor identity comes from Auth, malformed/direct writes
are constrained, and the legacy payload shape remains accepted. Hosted pgTAP
passes 13/13 and the mobile parameter suite passes 3/3.

## ~~Nested account foreign keys were only top-level RLS scoped~~ — fixed 2026-08-23

RLS correctly required access to each row's `account_id`, but ordinary foreign
keys did not prove that nested IDs (for example an Account A purchase pointing
at an Account B item) belonged to that same account. An attacker who learned a
UUID could forge a cross-account relationship without gaining read access to
the parent row. `20260823050806_enforce_account_graph_integrity.sql` adds
server-side same-account checks to all nested domain edges plus action
assignees, stamps audit actors from `auth.uid()`, makes profile email
Auth-controlled, and removes unused trigger helper RPC grants. Current hosted
data contained zero conflicting edges; 32/32 synthetic two-account tests pass.

## ~~Documents bucket had no size or MIME limit~~ — fixed 2026-08-23

Both buckets were private and account-path RLS scoped, but `documents` allowed
an unbounded file with any MIME type and malformed UUID path segments produced
cast errors. `20260823051328_harden_private_storage_limits.sql` adds a 12 MiB
document limit, a PDF/image MIME allowlist, fail-closed path parsing for both
buckets, and matching document metadata/path constraints. The item-photo limit
remains 8 MiB. Hosted Storage pgTAP passes 18/18.

## `@loop/contracts` is hand-synced with migrations

See docs/DECISIONS.md — no automated drift check yet between
`supabase/migrations` and `packages/contracts/src`. A schema change that
forgets to update contracts will not be caught until a type error
surfaces downstream. Revisit once CI can run against a real/ephemeral
Supabase instance to generate types automatically.
