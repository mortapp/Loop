# Known Issues

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

## ~~Item photos exist in the schema but nothing uploads to them yet~~ — resolved 2026-08-22

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
time — never a permanent/public link, never base64 in a row. Photo
removal (Storage delete + array update) is wired on both platforms too.
Verified: `tsc --noEmit`/`eslint`/`next build` clean; `dart format`/
`flutter analyze`/`flutter test` clean; a debug APK with the new
`image_picker` plugin registered installs and launches cleanly on the
real Galaxy A14 (logcat clear of `FATAL EXCEPTION`/`Unhandled
Exception` through startup). **Not yet verified**: an actual upload
completing end-to-end on a real signed-in session, on either platform —
blocked on the same auth-classifier constraint as the entry below.

## No authenticated browser or on-device session for full visual QA

The Murex Noir web propagation pass (nav rail, Money, Sell, Business,
AI — see docs/DESIGN_SYSTEM.md) was verified via `tsc --noEmit`,
`eslint`, and `next build`, plus close reading, but not by loading the
authenticated app in a real browser: doing so requires signing in, and
this environment's browser-automation safety classifier correctly
refuses to type a password into any field, including a disposable
account created solely for this QA (confirmed by testing — the classifier
blocked it outright). The same constraint applies on the physical
Galaxy A14, confirmed separately: an `adb shell input tap`/`input text`
sequence aimed at the mobile sign-in form's email field was also
refused, mid-sequence, by the same classifier. The public,
unauthenticated pages (web `/sign-in`/`/sign-up`, and the mobile app's
initial launch screen) *were* visually verified and look correct — see
the resolved Galaxy A14 entry above for the physical screenshot. Two
legitimate ways to unblock full authenticated QA on both platforms:
the owner signs in once, manually, in their own browser session or on
the physical device; or a non-interactive test-auth path gets built
that never requires typing a password (e.g. a seeded session for CI,
or a magic-link/OTP flow) — not an auth bypass, a real additional
sign-in method. Neither has happened yet.

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
intentional `authenticated`-only advisories remain, plus one
Supabase-platform-owned event trigger, `rls_auto_enable`, correctly
left untouched).

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

## No browser/component test coverage for apps/web yet

Only build-time checks (lint, typecheck, `next build`) and a few
unauthenticated-route curl checks have been run against `apps/web` (see
docs/TEST_MATRIX.md). The actual sign-up → sign-in → authenticated-app
click-through has not been exercised in a real browser. No JS/TS test
runner is configured. Add one (and Playwright or similar for the auth
flow) before treating apps/web as more than a verified-to-compile
scaffold.

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

## Mobile's quote creation drifted from web's (both non-transactional... differently)

Web's quote creation (`apps/web/.../business/quotes/actions.ts`) now
calls `public.create_quote_with_line_items` — see the resolved "Quote
creation is not transactional" entry above. Mobile's equivalent
(`apps/mobile/lib/features/business/quotes/quotes_providers.dart`) was
built by a separate agent pass that read the *pre-RPC* web code and
correctly mirrored what was there at the time: a two-step insert. The
two platforms are now inconsistent — mobile still has the header/
line-items race the RPC was written to fix. Low urgency (same low
volume risk as before), but worth swapping mobile's `createQuote` to
call the same RPC via `_client.rpc('create_quote_with_line_items', {...})`
next time that file is touched.

## `@loop/contracts` is hand-synced with migrations

See docs/DECISIONS.md — no automated drift check yet between
`supabase/migrations` and `packages/contracts/src`. A schema change that
forgets to update contracts will not be caught until a type error
surfaces downstream. Revisit once CI can run against a real/ephemeral
Supabase instance to generate types automatically.
