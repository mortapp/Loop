# LOOP Final State

Updated: 2026-08-24

`LOOP_FINAL_STATE=NOT_READY`

## Physical Certification

- Device: Samsung Galaxy A14 / SM-A146U over wireless ADB.
- Source: `385a787317b6fd6d2093a0f5e2190cbfd14740ba`.
- APK: `artifacts/ledger-2-385a787/loop-ledger-2-385a787-configured-debug-qa.apk`.
- SHA-256: `967ABD5BC393EE160E50AE5FCDD0A91193C51B3C5B6196939FDF22795A6D7A1A`.
- Core Today, Money, Protect, Sell, Business, Ask LOOP, account, 100%/150%
  text, rotation, background/resume, and repeated-navigation checks passed.
- Returning Google login reached the native existing-account Today route with
  no onboarding or web redirect.
- Final current-process logcat had zero relevant fatal, Flutter, layout,
  disposed-state, security, ANR/OOM, or auth-callback errors.

### Follow-up physical pass — Sell listing preparation

- Source: `48a0184` (built outside OneDrive; see "OneDrive build locking" in
  `docs/KNOWN_ISSUES.md`).
- APK: `artifacts/final-head-48a0184/loop-48a0184-configured-debug-qa.apk`.
- SHA-256:
  `0cec8c5e09064388810fab383b150dace7ccbebea62828fe7844c982827769fb`.
- Installed with `adb install -r`, preserving the existing session (no
  sign-out).
- Verified physically: Copy/Share/Export on an owned and a listed item
  (clipboard write, real Android share sheet with correct preview text,
  correctly named `listing.txt` export); a pre-existing returned item shows
  no listing/sale/Copy/Share/Export controls; a fresh item's full
  owned → listed (eBay $9.99) → sold lifecycle, with the sale posting
  `+$9.99` to Money immediately; background/resume; and a clean
  current-process logcat throughout.
- Not covered in this follow-up pass: 100%/150% text, rotation, multi-line
  quote, alternate-account switch, sign-out/returning-user login (session was
  preserved, not re-authenticated).

### Follow-up physical pass — multi-line quote

- Same APK/source as above (`48a0184`).
- Created `Q-2026-2YGUY` for `QA c963f65 contact` with two line items
  (qty 1 @ $0.01, qty 2 @ $0.02); the server-computed total read exactly
  `Total: $0.05` before submission.
- Walked `draft` → `sent` (`Mark sent`) → `viewed` (`Mark viewed`) →
  `accepted` (`Mark accepted`); each transition used the exact button the
  UI offered for that state.
- Money's current value moved from $10.04 to $10.09 immediately, with
  exactly one new ledger row: `Accepted quote Q-2026-2YGUY · +$0.05`.
  Three separate previously-accepted quotes on the same account each show
  their own single, correctly-amounted Money event — no duplicates.
- Once accepted, the UI exposes no re-accept control (forward-only lifecycle
  actions only), so a same-quote UI retry could not be reproduced; the
  server-side exactly-once guarantee itself is covered by the 209-case
  database suite.
- Current-process logcat was clean throughout (filtered for
  FATAL/AndroidRuntime/E:flutter/FlutterError/PlatformException/ANR/OOM/
  SecurityException).

### Follow-up physical pass — Protect purchase/return/refund

- Same APK/source as above (`48a0184`).
- Added a purchase linked to `Claude QA Listing Item` (`Claude QA Vendor 2`,
  $9.99) and started a return, then walked `initiated` → `shipped` →
  `received` → `refunded` via the exact button offered at each state.
- Confirmed an empty refund amount is rejected ("Enter a valid refund
  amount.") before a valid `$9.99` succeeds.
- Money posted `Purchase from Claude QA Vendor 2 · -$9.99` on purchase and
  `Return refunded · +$9.99` on refund, exact amounts.
- The linked item's status flipped live from `sold` to `returned` as a
  direct result of the refund, and Sell picked up that fresh status on its
  next fetch, showing only `+ Photo`/`+ Valuation` — confirming the
  eligibility fix against a freshly-written status, not only the
  already-tested static fixture.
- A second, unlinked purchase correctly refused to start a return ("No item
  linked — can't start a return.").
- Current-process logcat was clean throughout.

### Follow-up physical pass — 100%/150% text and rotation

- Same APK/session as above. Set `system font_scale` to `1.5` via `adb shell
  settings put` and swept all five primary tabs (Today, Money, Sell,
  Business, Ask LOOP): text reflows and wraps correctly, no clipped
  controls, no `RenderFlex` overflow.
- Rotated to landscape (`user_rotation 1`): the Ask LOOP composer, send
  button, and on-screen keyboard all render and remain usable; the primary
  nav stays reachable.
- Restored `user_rotation 0`, `accelerometer_rotation 1`, and `font_scale
  1.0` afterward. Logcat (filtered for FATAL/AndroidRuntime/E:flutter/
  FlutterError/PlatformException/ANR/OOM/SecurityException/RenderFlex) was
  clean throughout.

## Repair Verified

Physical QA found unreadable option cards in Light appearance mode. Commit
`385a787` replaced hardcoded dark surfaces with theme-derived colors and added
a Galaxy A14 contrast regression test. `flutter analyze --no-pub`, the focused
test, the 94-test Flutter suite, the configured APK build, installation, and
physical Light-mode retest passed.

## Why Not Ready

- Sell Copy/Share/Export, the returned/disposed listing-action mismatch, and
  multiple-line quote creation are implemented, tested, and now physically
  re-certified on the Galaxy A14 (see the "Follow-up physical pass" sections
  above and `docs/KNOWN_ISSUES.md`).
- The Protect purchase/return/refund lifecycle is also now physically
  re-certified (see "Follow-up physical pass — Protect purchase/return/
  refund" above), including the empty-refund-amount rejection and the live
  `sold` → `returned` ownership transition.
- A real alternate-account isolation switch was not completed physically.
- A warranty claim mutation was not recreated in this run.
- A valid Flutter frame-timing profile was not captured.
- Live AI, authenticated Playwright, native iOS, legal/privacy, operational,
  release-signing, and public-release approvals remain external gates.

This is a closed-test certification record, not production readiness or public
release authorization.
