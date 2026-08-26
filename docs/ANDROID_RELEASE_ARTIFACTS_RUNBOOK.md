# Android Release Artifacts Runbook

Updated: 2026-08-25

## What was audited tonight

Source: `apps/mobile/android/app/build.gradle.kts`,
`apps/mobile/android/app/src/main/AndroidManifest.xml`, plus a real
`flutter build appbundle --release` and `flutter build apk --release` dry
run from the physically-certified runtime commit `48a0184`, built in a
worktree outside OneDrive (`C:\loop-build\loop-48a0184`) for the same
Gradle-output file-lock reason documented in `docs/KNOWN_ISSUES.md`.

## Release signing — the one real gap

`apps/mobile/android/app/build.gradle.kts` contains, unmodified from the
Flutter template:

```kotlin
buildTypes {
    release {
        // TODO: Add your own signing config for the release build.
        // Signing with the debug keys for now, so `flutter run --release` works.
        signingConfig = signingConfigs.getByName("debug")
    }
}
```

Verified directly: `apksigner verify --print-certs` on tonight's release
build shows `Signer #1 certificate DN: C=US, O=Android, CN=Android Debug`
— the same debug certificate as every QA build. **A `flutter build
appbundle --release` or `flutter build apk --release` run today produces a
debug-signed artifact, not a production one.** This is not a regression —
it's the stock template default, never overridden, because no production
keystore has ever been configured. This was not changed tonight: creating
or storing a production signing keystore is an identity decision only the
owner can make (losing it permanently blocks future updates to the same
Play listing), so it is not something to fabricate autonomously.

`RELEASE_SIGNING=OWNER_ACTION_REQUIRED`. See
`docs/OWNER_RELEASE_ACTION_CENTER.md` for the exact steps.

## Everything else the dry run verified

- **Compilation**: `flutter build appbundle --release --no-pub` and
  `flutter build apk --release --no-pub` both completed with exit code 0.
- **R8/shrinking**: AAB is 43.0MB and the release APK is 53.7MB, versus the
  162MB debug QA APK. `mapping.txt` was generated
  (`build/app/outputs/mapping/release/mapping.txt`, SHA-256
  `eb1101ba1b88f7a51465f897e3e83fc26aa1669d26a1c626eb344a2a5643f741`).
- **Tree-shaking**: `CupertinoIcons.ttf` reduced 257,628→848 bytes (99.7%),
  `MaterialIcons-Regular.otf` reduced 1,645,184→4,616 bytes (99.7%).
- **Manifest**: the release build's merged manifest has no `debuggable`
  attribute at all (defaults to `false`), versus the debug APK's explicit
  `android:debuggable="true"`. Verified with `apkanalyzer manifest print`.
- **AAB generation**: succeeded —
  `build/app/outputs/bundle/release/app-release.aab`, SHA-256
  `8ce062e44f594b0cccafa4d216a2f8d9bbb0666e7328ae68fe0efb333d4b9ea1`.
- **16KB native-page-size compatibility**: `zipalign -c -P 16 -v` on the
  release APK reported "Verification successful" — the packaged
  `lib/<abi>/*.so` files (all standard Flutter engine/runtime libraries:
  `libapp.so`, `libflutter.so`, `libdartjni.so`,
  `libdatastore_shared_counter.so` — no third-party native libraries beyond
  the Flutter/AndroidX stack) are already 16KB-page aligned. No action
  needed.
- **Identity**: `com.loop.app.loop_mobile`, version `1.0.0`, unchanged.

These two dry-run artifacts are saved, clearly labeled, at
`artifacts/release-dry-run-48a0184/` —
`loop-48a0184-release-DEBUG-SIGNED-DRY-RUN.aab`,
`loop-48a0184-release-DEBUG-SIGNED-DRY-RUN.apk`, and `mapping.txt`. **Do
not distribute these as if they were production artifacts** — they exist
only to prove the release build pipeline itself works. They were built
without `--dart-define-from-file`, so they also don't carry real Supabase
configuration and will not authenticate against anything.

## What to do once a real production keystore exists

1. Generate/obtain the production keystore and its passwords through your
   own secure process (Play App Signing is recommended — Google holds the
   upload key exchange, you never need to reproduce Google's signing key).
2. Add a `signingConfigs.create("release")` block in
   `apps/mobile/android/app/build.gradle.kts` referencing the keystore via
   Gradle properties (`key.properties`-style, gitignored — never commit
   keystore passwords), and point `buildTypes.release.signingConfig` at it
   instead of `signingConfigs.getByName("debug")`.
3. Rebuild: `flutter build appbundle --release
   --dart-define-from-file=dart_define.json`.
4. Re-verify: `apksigner verify --print-certs` should show your production
   certificate, not `CN=Android Debug`.
5. Re-run `zipalign -c -P 16` and the manifest/debuggable check above as a
   final sanity pass on the real artifact.
6. Retain per release: the `.aab`, `mapping.txt` (needed to de-obfuscate
   Play Console crash reports), the SHA-256 of the `.aab`, the exact Git
   commit it was built from, and the version name/code. A simple
   `artifacts/release-<version>-<shortsha>/` folder following this
   session's existing convention works well.

## Versioning

See `docs/RELEASE_VERSIONING.md` for the versionCode/versionName strategy
— not changed tonight, since no release is being cut.
