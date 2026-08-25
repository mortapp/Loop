# Claude Final Completion Run

Updated: 2026-08-24

Recovery ledger for the Claude session resuming after Codex's interrupted
blocker-closure pass. Existing for continuity if this session stops; not a
substitute for `docs/KNOWN_ISSUES.md` or `docs/LOOP_FINAL_STATE.md`.

## Start state (verified, not assumed)

- `START_HEAD=ff5dc4d5a57b1b902f7cd5eaf99e386adba735b1`
- `START_ORIGIN_MAIN=46c9c98e3114b2db2a3426f968117271dc8a0f37` (local was 2
  commits ahead: `385a787`, `ff5dc4d`)
- `START_DIRTY_FILES=apps/mobile/pubspec.yaml, apps/mobile/pubspec.lock`
  (only). No Dart/TS source changes were left uncommitted by Codex — its
  root-cause finding on the returned-item mismatch was not yet turned into
  code.
- `CODEX_DEPENDENCY_CHANGES=share_plus ^13.3.0, cross_file ^0.3.5+4` added to
  `apps/mobile/pubspec.yaml` (and resolved in `pubspec.lock`). Verified both
  are actually used by the new listing-preparation code below, so both were
  kept.
- Historical QA screenshots/APKs under `artifacts/` and a stray
  `supabase/.temp.pre-link-20260823/` were untracked and left untouched
  (evidence from prior runs, not this session's concern).

## Work completed this pass

1. **Sell listing preparation (Copy/Share/Export)**, real device
   clipboard/share-sheet/file-export, no fake marketplace publish:
   - `apps/mobile/lib/features/sell/listing_text.dart` (new) — canonical
     listing text formatter (name, category/condition, active listing price
     or latest valuation; no ids/paths).
   - `apps/mobile/lib/features/sell/listing_preparation_actions.dart` (new)
     — Copy (`Clipboard`), Share (`SharePlus.instance.share`), Export
     (`XFile.fromData` + share sheet as `.txt`).
   - `apps/web/src/app/(app)/sell/listing-text.ts` (new) — same formatter,
     web-side.
   - `apps/web/src/app/(app)/sell/listing-preparation.tsx` (new) — Copy
     (`navigator.clipboard`), Share (Web Share API, falls back to copy),
     Export (Blob download).
2. **Returned/disposed listing-action mismatch fixed**: added
   `canPrepareListing`/`canRecordSale` to
   `apps/mobile/lib/features/sell/models/item.dart` and
   `packages/contracts/src/core.ts`, mirroring the server's
   `owned`/`listed`-only rule in `guard_listing_lifecycle`/
   `guard_sale_lifecycle`
   (`supabase/migrations/20260823060632_enforce_atomic_money_lifecycle.sql`).
   Wired into `item_actions.dart`, `sell_screen.dart`, and
   `apps/web/src/app/(app)/sell/page.tsx` in place of the old
   `status != sold` check.
3. **Root-cause build fix**: `packages/contracts/src/index.ts` used `.js`
   relative-export extensions (valid under `moduleResolution: "Bundler"` for
   `tsc`, but unresolvable by Next's Turbopack bundler, which has no
   `.js`-to-`.ts` extension aliasing). This was latent — every prior web
   import from `@loop/contracts` was type-only and got erased before
   bundling, so it never executed. `canPrepareListing` is the first runtime
   value import from that package, and it broke the production build.
   Fixed by dropping the extensions (valid and idiomatic under Bundler
   resolution) rather than adding bundler config.
4. Added regression tests: `listing_eligibility_test.dart`,
   `listing_text_test.dart` (Flutter).
5. Updated `docs/KNOWN_ISSUES.md` and `docs/LOOP_FINAL_STATE.md` to reflect
   the above; corrected a stale Flutter test count in `docs/TEST_MATRIX.md`.

## Verified locally (this pass)

- `dart format --output=none --set-exit-if-changed lib test` — clean.
- `flutter analyze --no-pub` — no issues.
- `flutter test --no-pub --concurrency=1` — 99/99 pass (94 baseline + 5 new).
- `npm run typecheck --workspaces --if-present` — clean.
- `npm run lint --workspaces --if-present` — clean.
- `npm run build --workspace apps/web` — production build succeeds, 24 routes.
- `npm run test:unit` (web) — 4/4 pass, unchanged.
- `npx playwright test` (web) — 31 pass, 60 credential-gated skips, 0 fail —
  matches the documented baseline exactly.

## Not done in this pass (explicit blockers, not silently skipped)

- **No new configured QA APK built, no Galaxy A14 install/physical retest.**
  The device's current connection state has not been checked in this
  session. Needs `adb devices -l` (wireless) before anything physical.
- **Multi-line quote physical test** ($0.05 two-line quote, lifecycle
  transitions, exactly-once Money event) — not attempted this pass.
- **Protect `PASS_WITH_LIMITATIONS` resolution** — not investigated this
  pass beyond what's already in `KNOWN_ISSUES.md`.
- **Hosted Supabase**: no migration was needed for the eligibility fix (the
  server guard already enforced the correct rule; only the clients were
  wrong), so nothing was applied to the hosted project this pass.
- **Git**: changes are committed locally but not yet pushed to
  `origin/main` as of this checkpoint — see current `git status`/`git log`
  for the authoritative state.
- **Vercel/GitHub CI**: not triggered this pass.

## Physical pass (checkpoint 2)

Owner confirmed the Galaxy A14 was reachable and asked to proceed. Built a
new configured QA APK from `48a0184` in a worktree outside OneDrive
(`C:\loop-build\loop-48a0184`) after `flutter build apk` failed in place
with a Gradle "Unable to delete directory ... mergeDebugResources" error —
see "OneDrive build locking" in `docs/KNOWN_ISSUES.md`.

- `FINAL_RUNTIME_COMMIT=48a0184`
- `FINAL_QA_APK=artifacts/final-head-48a0184/loop-48a0184-configured-debug-qa.apk`
- `FINAL_QA_APK_SHA256=0cec8c5e09064388810fab383b150dace7ccbebea62828fe7844c982827769fb`
- Signature: v2, Android debug certificate. Package
  `com.loop.app.loop_mobile` `1.0.0`, minSdk 24, targetSdk 36.
- Secret scan of the extracted APK: no matches.
- Installed with `adb install -r`, session preserved (no sign-out, no
  re-auth).

Physically verified: Copy/Share/Export (clipboard, native share sheet with
correct preview text, correctly-named `listing.txt` export) on both an owned
and a listed item; a pre-existing returned item correctly shows no
listing/sale/Copy/Share/Export controls; a fresh item's full
owned → listed (eBay, $9.99) → sold lifecycle with the sale posting `+$9.99`
to Money immediately; background/resume; clean current-process logcat
throughout (no FATAL/AndroidRuntime/E:flutter/FlutterError/
PlatformException/ANR/OOM/SecurityException).

Not covered in this pass: 100%/150% text and rotation, multi-line quote
physical test, alternate-account switch, sign-out/returning-user Google
login (deferred — session was preserved throughout, deliberately not
re-authenticated).

## Physical pass (checkpoint 3) — multi-line quote

Owner asked to continue. Same APK/session as checkpoint 2 (`48a0184`, no
reinstall needed — runtime code did not change for this test). Created a
two-line quote for `QA c963f65 contact` (qty 1 @ $0.01, qty 2 @ $0.02),
confirmed the server-computed total read exactly `$0.05` before submitting,
then walked `draft` → `sent` → `viewed` → `accepted` via the exact button
the UI offered at each state. Money's current value moved $10.04 → $10.09
immediately, with exactly one new ledger row (`+$0.05`); the other three
already-accepted quotes on the account each show their own single,
correctly-amounted event — no duplicates anywhere in the ledger. Once
accepted, the UI exposes no re-accept control, so a same-quote UI-level
retry isn't reproducible by design; the underlying exactly-once guarantee
is covered by the 209-case database suite. Logcat clean throughout.

`MULTILINE_QUOTE_PHYSICAL=PASS`, `QUOTE_SERVER_TOTAL=PASS`,
`QUOTE_ACCEPTANCE_MONEY_PHYSICAL=PASS`.

## Next action

The remaining Protect `PASS_WITH_LIMITATIONS` gaps, then 100%/150% text and
rotation, then sign-out-last + owner-assisted returning-user Google login.
