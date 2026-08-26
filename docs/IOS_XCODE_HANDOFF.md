# iOS / Xcode Handoff

Updated: 2026-08-25

Windows cannot run Xcode or CocoaPods, so **no real iOS build, simulator
run, or device test has ever happened for LOOP.** Everything below is
static source/config parity review only — verified by reading the actual
`ios/` project files, not assumed.

`IOS_SOURCE_PARITY=PASS` (evidence below).
`IOS_REAL_BUILD=EXTERNAL_BLOCKER_MACOS_XCODE`.

## What was verified tonight

| Item | Android | iOS | Match? |
| --- | --- | --- | --- |
| OAuth/email-confirmation callback scheme | `com.loop.app.loop-mobile://app/login-callback` (`AndroidManifest.xml` intent-filter) | `com.loop.app.loop-mobile` (`Info.plist` `CFBundleURLSchemes`) | **Yes** — identical, both derived from the single Dart source of truth `lib/core/auth/mobile_auth_contract.dart` |
| App identifier | `com.loop.app.loop_mobile` (Android package names allow underscores) | `com.loop.app.loopMobile` (`PRODUCT_BUNDLE_IDENTIFIER` — iOS bundle IDs cannot contain underscores) | **Intentionally different strings, correctly so** — this is not a parity bug; only the OAuth *scheme* needs to match across platforms, and it does |
| Display name | `android:label="LOOP"` | `CFBundleDisplayName = LOOP` | Yes |
| Photo permission | No manifest permission needed (system Photo Picker) | `NSPhotoLibraryUsageDescription`: "LOOP needs access to your photos so you can add a picture of an item you're selling." | Present and accurately describes the actual feature (Sell item photos) |
| Camera permission | Not requested | Not present in `Info.plist` — consistent with not using native camera capture on either platform | Yes |
| Network access | `usesCleartextTraffic="false"` (blocks plaintext HTTP) | No manifest-level equivalent exists on iOS — Apple's App Transport Security defaults to HTTPS-only unless explicitly relaxed, and nothing in `Info.plist` relaxes it | Equivalent security posture, no code needed on iOS |
| Version/build number | Read from `pubspec.yaml` via Flutter's Gradle integration | Read from `pubspec.yaml` via `$(FLUTTER_BUILD_NUMBER)`/generated Xcode config | Yes, single source of truth |
| Minimum OS version | `minSdk = flutter.minSdkVersion` (24, i.e. Android 7.0) | `IPHONEOS_DEPLOYMENT_TARGET = 13.0` (stock Flutter template default, never changed) | Both are template defaults; iOS 13.0 is worth a deliberate decision before release (see below), not a parity concern |

## Plugin/dependency compatibility

Every plugin currently in `pubspec.yaml` (`supabase_flutter`, `go_router`,
`google_fonts`, `image_picker`, `shared_preferences`, `http`, `share_plus`,
`cross_file`, `flutter_riverpod`, `app_links`) ships official iOS support
— none of them are Android-only packages. `share_plus`'s Export-listing
mechanism (`XFile.fromData` + the native share sheet) is the same
cross-platform API used on Android; iOS's native share sheet is the
platform equivalent, but this has never been physically exercised on a
real iPhone.

## What has NOT been verified (cannot be, without macOS)

- Whether `pod install` succeeds cleanly (no `Podfile.lock` exists yet in
  this checkout, meaning CocoaPods has likely never been run for this
  project on any machine).
- Real Xcode build success (compilation, code signing, embedding).
- Real device behavior: OAuth browser hand-off and callback, photo
  picker, share sheet, background/resume, Dynamic Type (iOS's equivalent
  of Android's font-scale test), Dark/Light appearance switching.
- App Store Connect provisioning/signing (a completely separate identity
  and process from Android's release signing — see
  `docs/ANDROID_RELEASE_ARTIFACTS_RUNBOOK.md` for the Android equivalent;
  don't assume anything about one transfers to the other).
- TestFlight distribution.

## Exact steps for whoever has macOS/Xcode next

1. `flutter pub get` from `apps/mobile/`.
2. `cd ios && pod install` — this will be the first time CocoaPods has run
   for this project; expect it to take a while and to generate
   `Podfile.lock` for the first time.
3. Open `ios/Runner.xcworkspace` (not `.xcodeproj`) in Xcode.
4. Set up signing: Xcode → Runner target → Signing & Capabilities → select
   your Apple Developer team. This requires an active Apple Developer
   Program membership — separate from anything Android needs.
5. Build and run on a real device or the simulator:
   `flutter build ios --dart-define-from-file=dart_define.json` or run
   directly from Xcode.
6. Walk the same physical QA sequence this session ran on the Galaxy A14
   (`docs/CLAUDE_FINAL_COMPLETION_RUN.md` and `docs/LOOP_FINAL_STATE.md`
   document the exact sequence and expected results): Today, Money, Sell
   (including Copy/Share/Export), Business (including a multi-line
   quote), Protect (purchase/return/refund), Ask LOOP, sign-out, then a
   real Google sign-in with the account owner tapping their own account
   (never automate that step — same rule as the Android testing this
   session did).
7. Decide on `IPHONEOS_DEPLOYMENT_TARGET` deliberately before release —
   13.0 is very old (2019) and most apps targeting a 2026 release use a
   materially higher floor; check current App Store Connect minimum-OS
   analytics/guidance rather than picking a number arbitrarily. This is a
   one-line change in `project.pbxproj` once decided, not urgent tonight.
8. Only after a real physical iPhone pass should `IOS_REAL_BUILD` change
   from `EXTERNAL_BLOCKER_MACOS_XCODE` to `PASS`.
