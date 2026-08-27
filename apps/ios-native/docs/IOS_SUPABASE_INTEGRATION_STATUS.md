# LOOP Native iOS Supabase Integration Status

Updated: 2026-08-26

## Completed in source

- Replaced the prototype/legacy backend adapter with the actual hosted LOOP schema and RPC contract.
- Connected production Supabase project `zqalnvfwxmfrnyjcuehq` with its public publishable key.
- Matched LOOP's established browser PKCE login callback: `com.loop.app.loop_mobile://login-callback`.
- Registered both the normal `loop://` deep-link scheme and the OAuth callback scheme in `LOOP/Info.plist`.
- Moved Money, Protect, Sell, Business, Today, Search, onboarding, documents and Ask LOOP onto real backend records/endpoints.
- Kept financial and lifecycle mutations behind existing atomic RPCs where those RPCs are authoritative.
- Kept private Storage private and provider/server secrets out of the target.
- Changed the Xcode target away from the generated Rork bundle identifier to `com.loop.app.loop_ios`.

## Verification performed in this environment

- Every Swift source file parses successfully with the available Swift compiler frontend.
- `LOOP/Info.plist` passes `plutil` validation.
- Static scans reject the old fabricated table/RPC contract from shipping Swift code.
- Project configuration references `LOOP/Info.plist` and the native LOOP bundle identifier.

## Verification that still requires macOS/Xcode

This environment cannot run `xcodebuild`, resolve an Apple signing team, boot an iOS Simulator, or install on a physical iPhone. Therefore this integration must **not** be described as a compiled or physically certified iOS build yet.

On the first Mac pass, run the project tests, build the main target, exercise Google → Supabase → native callback, verify returning-user routing, and walk the five primary LOOP surfaces against the same hosted account before release signing.

## Repository placement

This project is prepared to live inside the existing LOOP monorepo as:

`apps/ios-native/`

It should be committed as an additive native client. The existing `apps/mobile` Flutter client, `apps/web`, `supabase`, migrations, and backend contracts should remain intact.
