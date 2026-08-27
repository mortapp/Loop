# Native SwiftUI iOS Status

## Scope

`apps/ios-native` is a native SwiftUI client in the existing LOOP monorepo. It is additive: `apps/mobile` and its Flutter iOS directory remain the Flutter client and are not replaced.

## Shared backend contract

- Supabase project: `zqalnvfwxmfrnyjcuehq` at `https://zqalnvfwxmfrnyjcuehq.supabase.co`.
- Bundle ID: `com.loop.app.loop_ios`.
- OAuth: Supabase PKCE through `ASWebAuthenticationSession`, using the already-canonical `com.loop.app.loop_mobile://login-callback` callback. The callback scheme is intentionally separate from the native app bundle ID.
- Session and PKCE verifier: iOS Keychain only.
- Ask LOOP: authenticated calls to LOOP's deployed server API; no provider key is in the app.
- Money: integer-cent payloads and the canonical purchase, listing, sale, refund, quote, totals, and Today RPCs.
- Storage: private document access uses signed URLs; access remains enforced by Supabase RLS and Storage policies.

## Validation evidence

Windows ran `scripts/validate-ios-native.ps1`, which checks the configured project, bundle ID, callback, canonical tables/RPCs, contact/lead search routing, required project files, and forbidden runtime references. Python `plistlib` also parsed `LOOP/Info.plist` successfully.

`.github/workflows/ios-native-ci.yml` supplies the remaining build check on `macos-latest` using a generic iOS Simulator destination and disabled code signing. It deliberately does not publish or sign the app.

## macOS/Xcode handoff

1. Clone the repository and open `apps/ios-native/LOOP.xcodeproj` in Xcode.
2. Select the `LOOP` scheme and an iOS Simulator, then build and run.
3. Confirm the URL scheme `com.loop.app.loop_mobile` is registered in the Supabase Auth redirect allow-list and Google OAuth configuration.
4. Sign in with Google, select the existing LOOP account, and exercise Today, Money, Sell, Business, and Ask LOOP with real RLS-protected data.
5. Run the `LOOPTests` and `LOOPUITests` targets. Complete physical iPhone and signing certification separately.

This source integration is not a claim of a local Xcode build, Simulator run, physical iPhone QA, TestFlight upload, or App Store readiness.
