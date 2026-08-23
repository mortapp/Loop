# LOOP Codex Primary Finishing Progress

Updated: 2026-08-23T00:11:10-04:00

## Repository

- Active repository: `C:\Users\micha\OneDrive\Desktop\Loop`
- Branch: `main`
- Starting HEAD: `40692e8fdb22284b57b0a8e0742e585b1f177e4e`
- Remote: `git@github.com:mortapp/Loop.git`
- Remote relation: local is one commit ahead of `origin/main`
- Source version: `1.0.0+1`
- MORT status: reference-only; not modified

## Current Phase

`PHASE 1 - native Google OAuth, session ownership, and onboarding integrity`

## Verified Evidence

- Hosted Supabase project `zqalnvfwxmfrnyjcuehq` is active.
- Google and email authentication are enabled.
- The exact mobile callback and its prior form are already allow-listed.
- The installed Android app emits the legacy-invalid `com.loop.app.loop_mobile://app/login-callback` as `redirect_to`.
- Root cause found by regression test: underscores are illegal in URI schemes, so Dart cannot parse that callback for PKCE exchange.
- Supabase Flutter `2.17.2` owns PKCE callback exchange through `app_links`.
- The current UI clears Google loading as soon as the browser launches instead of waiting for a valid session.
- The current onboarding save performs display name and username writes separately.
- The current router considers only display name when deciding onboarding completion.

## Physical QA

- Device: Samsung SM-A146U, Android API 35
- Wireless ADB serial: `10.0.0.151:33757`
- Package: `com.loop.app.loop_mobile`
- Installed version: `1.0.0+1`
- Current gate: owner must complete Google account selection; LOOP is backgrounded and the launcher is foreground.

## Active Work

- Main agent: standards-valid callback migration, PKCE bootstrap policy, OAuth coordinator, secure router/profile gate, atomic profile completion.
- Sosa: native onboarding UI and focused widget tests in a disjoint file scope.
- Wireless QA agent: read-only Samsung gauntlet; waiting for an installable build or owner callback completion.

## External Gates

- Google account selection requires the owner on the physical phone.
- iOS Xcode, signing, TestFlight, and physical iPhone validation require Apple tooling and credentials.

## Next Automatic Checkpoint

Focused auth/profile tests, analyzer, configured APK build, then wireless Samsung callback/session/onboarding verification.
