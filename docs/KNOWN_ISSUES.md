# LOOP Known Issues and External Gates

Updated: 2026-08-24

## Open External Gates

### Remaining Ledger 2.0 physical gaps

The Galaxy A14 physical run is complete for the core authenticated journey,
and Sell Copy/Share/Export plus the returned-item eligibility fix are now
physically re-certified. The current configured APK, built from
`48a0184` in a detached worktree outside OneDrive (Gradle's output
directory could not be cleaned in place — see "OneDrive build locking"
below), is
`artifacts/final-head-48a0184/loop-48a0184-configured-debug-qa.apk`
(SHA-256
`0cec8c5e09064388810fab383b150dace7ccbebea62828fe7844c982827769fb`,
v2-signed with the Android debug certificate,
`com.loop.app.loop_mobile` `1.0.0`, minSdk 24 / targetSdk 36, no
secret-shaped strings found in the extracted APK). Installed with `adb
install -r`, preserving the existing session.

Physically verified this pass on that APK:

- Copy writes the canonical listing text to the clipboard (confirmed by
  both the app's own snackbar and the system's native "Copied to
  clipboard" toast).
- Share opens the real Android share sheet with the correct preview text
  — `<name>` alone for an unlisted item, `<name>\nAsking $9.99 on eBay`
  once listed — and was safely dismissed without sending anywhere.
- Export opens the share sheet with a correctly named `listing.txt` file
  attachment (not a random/generic name), proving the
  `fileNameOverrides` handling for `XFile.fromData` is correct on
  Android.
- A previously-existing **returned** item (`QA c963f65 item`) shows only
  `+ Photo`/`+ Valuation` — no `List for sale`, no `Record sale`/`Sold
  already?`, no Copy/Share/Export row — confirming the eligibility fix
  live, not just in tests.
- A fresh item walked through the full `owned` → `listed` (eBay, $9.99)
  → `sold` lifecycle: `List for sale`/`Sold already?` and Copy/Share/
  Export appeared while owned; only `Record sale` (primary) and Copy/
  Share/Export appeared once listed; no actions once sold. The recorded
  sale posted `Item sold via RECOVER · +$9.99` to Money immediately.
- Background/resume and current-process logcat (filtered for
  FATAL/AndroidRuntime/E:flutter/FlutterError/PlatformException/ANR/
  OOM/SecurityException) were clean throughout.

Multiple-line quote creation is now physically verified too: a two-line
quote (qty 1 @ $0.01, qty 2 @ $0.02) on the same APK produced a
server-computed total of exactly $0.05 (`Q-2026-2YGUY`), and walking it
through `draft` → `sent` → `viewed` → `accepted` posted exactly one
`Accepted quote Q-2026-2YGUY · +$0.05` event to Money immediately (current
value moved from $10.04 to $10.09). Once accepted, the UI offers no
re-accept control — only forward-only lifecycle actions are ever shown, and
the same account's ledger shows three separate accepted quotes with three
separate, correctly-amounted Money events (no duplicates for any one quote).
The server-side exactly-once/idempotency guarantee itself is covered by the
209-case database suite; this pass confirms the client path posts correctly
against the real hosted backend.

The Protect purchase/return/refund lifecycle is now physically verified end
to end too, closing the prior `PASS_WITH_LIMITATIONS` gap: a purchase linked
to `Claude QA Listing Item` ($9.99, `Claude QA Vendor 2`) was walked through
`initiated` → `shipped` → `received` → `refunded`. Confirming an empty
refund amount was correctly rejected ("Enter a valid refund amount.")
before a valid `$9.99` succeeded. Money posted `Purchase from Claude QA
Vendor 2 · -$9.99` on purchase and `Return refunded · +$9.99` on refund —
exact amounts, no drift. The linked item's own status flipped live from
`sold` to `returned` as a direct result of the refund RPC (not a
pre-existing fixture), and the Sell screen picked up that fresh status on
its next fetch: `Claude QA Listing Item` now shows only
`+ Photo`/`+ Valuation`, confirming `canPrepareListing`/`canRecordSale`
correctly evaluate a freshly-written `returned` status, not just the
already-tested static fixture from an earlier session. A second, unlinked
purchase correctly refused to start a return ("No item linked — can't
start a return."). Logcat was
clean throughout.

Remaining gaps are narrower: a real alternate-account switch was not
completed physically, and no valid Flutter frame-timing profile was
captured. These are not represented as passed.

### OneDrive build locking

Building `flutter build apk` directly inside
`C:\Users\micha\OneDrive\Desktop\Loop\apps\mobile` failed with `Unable to
delete directory ... mergeDebugResources\out` — OneDrive briefly locks files
under `build\` while syncing, which Gradle's incremental clean cannot work
around. Building in a `git worktree` outside OneDrive
(`C:\loop-build\loop-<sha>`) and copying the resulting APK back into
`artifacts/` avoids this reliably; this does not indicate a source-code
defect.

### Live AI provider

`ANTHROPIC_API_KEY` is unavailable locally. The authorization, confirmation,
account binding, tamper resistance, expiration, and exactly-once database path
are implemented and tested. A live model response has not been fabricated.
Configure the key server-side only, then run one controlled provider call and
the authenticated Ask LOOP device/web journeys.

### Authenticated Playwright

The suite discovers 91 tests. Thirty-one public/guard tests pass and 60 real
authenticated tests intentionally skip when `QA_TEST_EMAIL` and
`QA_TEST_PASSWORD` are absent. Create a dedicated, non-owner QA Supabase user
and store those values as GitHub Actions secrets. Never use the owner's primary
credentials in CI.

### Native iOS

Shared Flutter source and iOS configuration pass static parity review. A real
Xcode build, Apple signing, TestFlight, and iPhone QA require macOS/Xcode and
Apple credentials. No Windows result substitutes for those gates.

### Manual accessibility and release review

Automated public axe coverage, Flutter semantics-focused tests, large-text
auth/onboarding tests, touch-target checks, and Samsung layout tests pass.
Authenticated screen-reader and keyboard journeys still need manual QA on the
final device builds. Release also needs product, privacy, legal, and operational
approval; this document does not provide those approvals.

## Deferred - Plan-Limited Security Enhancement

Supabase leaked-password protection cannot be enabled on the Free plan. This is
not an unresolved code security bug.

Current mitigations:

- strong password minimum length
- required password complexity in the clients
- Auth rate limiting
- email verification policy
- RLS and account graph restrictions
- secure password reset flow

Future task: **When Supabase is upgraded to Pro, enable leaked-password
protection immediately and rerun Auth security advisors.** Do not upgrade or
spend money solely from this task.

## Advisor Findings Accepted With Evidence

- Seven authenticated-executable `SECURITY DEFINER` functions remain:
  `create_quote_with_line_items`, `has_account_access`,
  `is_active_business_member`, `is_business_admin`,
  `is_username_available`, `set_quote_status_with_money_event`, and
  `shares_active_business`. The quote functions are
  the narrow validated write authority after direct quote creation and line
  mutation were revoked, and accepted status atomically writes one Money event.
  The others are search-path-hardened recursion breakers or boolean helpers used
  by RLS. Anonymous/PUBLIC execution is revoked. Their authorization behavior is
  covered by the 209-case database suite.
- Performance advisor notices are unused-index INFO entries on a low-traffic
  dataset. The indexes support known relationship, status, deadline, feed, and
  pagination queries. Reassess with production telemetry; do not drop them now.

## Resolved in the Final Pass

- Sell now has real Copy/Share/Export listing preparation on both platforms
  (clipboard write, native/Web Share, and a downloaded/shared `.txt` file of
  the canonical listing text — no ids, account ids, or Storage paths, and no
  fake marketplace publish). Mobile uses `share_plus`/`cross_file`; web uses
  `navigator.clipboard`, the Web Share API, and a Blob download.
- The Sell listing/sale action mismatch is fixed: client eligibility
  (`canPrepareListing`/`canRecordSale` in both the Flutter model and
  `@loop/contracts`) now matches the server's `guard_listing_lifecycle`/
  `guard_sale_lifecycle` triggers exactly (`owned`/`listed` only), so a
  returned or disposed item — which is not `sold` but is still
  server-rejected — no longer shows an action the backend refuses.
- AI proposals cannot survive an account switch or execute under a different
  user/account/tool/input.
- AI confirmation retries are exactly-once at the database boundary.
- Malformed Ask LOOP payloads and thrown gateway calls fail closed and clear the
  mobile loading state.
- Malformed, blank, non-finite, and negative quote prices are rejected; explicit
  zero remains valid.
- Money history is paginated rather than silently capped at 200 events.
- Item-photo attach/detach is atomic and no longer overwrites concurrent paths.
- Mobile business creation is real; the dead join/create card is gone.
- Clean-checkout web typecheck no longer depends on generated Next globals.
- CI is one authoritative workflow rather than three overlapping workflows.
- Icon-only account and quote-line controls now expose accessible names, with
  focused widget regression coverage.
- Fractional-cent, exponent, unsafe, and oversized money values are rejected
  consistently by web, Flutter, AI tool input, and Postgres constraints.
- Manual Money retries are exactly-once on web and mobile.
- Direct quote total, header, line, and delete mutations are denied; quote
  creation remains available only through its validated server function.

## Security Hygiene

No service role, Supabase access token, database password, Anthropic secret,
Google client secret, GitHub token, private key value, QA password, or ignored
`dart_define.json` is tracked. Public Supabase URL/client configuration remains
client-safe by design; privileged configuration stays server-side.
