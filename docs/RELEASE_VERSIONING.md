# Release Versioning Strategy

Updated: 2026-08-25

## Current state (verified, not changed tonight)

- `apps/mobile/pubspec.yaml`: `version: 1.0.0+1` — the single source of
  truth for both platforms.
- Android: `versionName`/`versionCode` in
  `apps/mobile/android/app/build.gradle.kts` read `flutter.versionName`/
  `flutter.versionCode`, which Flutter derives from `pubspec.yaml` at build
  time. Verified in the built release APK/AAB: `versionName=1.0.0`.
- iOS: `MARKETING_VERSION`/`CURRENT_PROJECT_VERSION` in
  `ios/Runner.xcodeproj/project.pbxproj` read `$(FLUTTER_BUILD_NUMBER)`/
  Flutter's generated build settings — same source of truth, no drift
  possible between platforms as long as builds go through `flutter build`.

No version bump happened tonight — there is no new release being cut, so
bumping `1.0.0+1` now would just be churn.

## The format

`pubspec.yaml`'s `version: X.Y.Z+B`:

- `X.Y.Z` — the user-facing semantic version (marketing version, iOS
  `MARKETING_VERSION`).
- `B` — the build number. On Android this becomes `versionCode`, which
  **must strictly increase with every artifact uploaded to Google Play**,
  across every track (internal, closed, open, production) — Play rejects
  an upload whose `versionCode` isn't higher than every previously uploaded
  one for that package, permanently. On iOS, `CURRENT_PROJECT_VERSION` has
  a similar per-`MARKETING_VERSION` monotonic requirement enforced by App
  Store Connect.

## Recommended strategy going forward

1. **Closed-test / internal builds** (what this session's QA APKs are):
   keep `X.Y.Z` at `1.0.0` and bump only `B` for every build that gets
   installed anywhere outside a throwaway local test — including
   physically-certified QA APKs like this session's `48a0184`. That keeps
   `versionCode` monotonic from the very first upload, so there's never a
   collision when the first real Play upload happens.
2. **First production candidate**: bump to `1.0.0+<next available B>` (or
   `1.0.1` if any user-visible fix landed after the last internal build) —
   the exact number doesn't matter, only that it's higher than anything
   ever installed via Play (internal testing tracks count against the
   Play-wide `versionCode` history for that package, even before a public
   release).
3. **Ongoing releases**: bump `Z` for a bug-fix-only release, `Y` for a
   release with new user-facing capability, `X` only for a deliberate
   product-scope change. Always bump `B` on every release regardless.

## Git commit ↔ artifact mapping

Every artifact this project has produced follows the same naming
convention: `artifacts/<label>-<shortsha>/loop-<shortsha>-<qualifier>.apk`
(or `.aab`). Keep doing this for real releases too:
`artifacts/release-<version>-<shortsha>/` holding the `.aab`, `mapping.txt`,
and a `LOOP_FINAL_CERTIFICATION.txt`-style manifest recording the exact
commit, version, and SHA-256. This makes "which commit is live in
production" a one-directory lookup instead of a guess, and lets a Play
Console crash report's obfuscated stack trace be de-obfuscated against the
exact `mapping.txt` for that `versionCode`.

## What NOT to do

- Don't bump the version merely because time passed in a session.
- Don't reuse a `versionCode`/build number that has ever touched any Play
  track, even internal testing — Play's monotonic check is global per
  package, not per-track.
- Don't let Android and iOS build numbers diverge by hand-editing one
  platform's project file directly — always go through `pubspec.yaml` so
  `flutter build` keeps both in sync.
