# Play Release Readiness

Updated: 2026-08-25

**Nothing in this document authorizes or performs a Play Console
submission.** It's a technical inventory of what's actually true about
this project's Android build, gathered from real inspection this session,
so a Play Console listing can be filled in accurately when the owner is
ready.

## Application identity

- `applicationId`: `com.loop.app.loop_mobile`
- Current version: `1.0.0`, build `1` (see `docs/RELEASE_VERSIONING.md`)
- `targetSdk`: 36, `minSdk`: 24, `compileSdk`: 36 (all Flutter-managed —
  `flutter.targetSdkVersion` etc. in `build.gradle.kts`)

## Permissions

Exactly two, one user-meaningless: see
`docs/ANDROID_PERMISSION_DECLARATION_INPUT.md`. `INTERNET` only, plus an
auto-generated AndroidX signature permission. No dangerous/runtime
permission is requested.

## Google sign-in architecture

Browser-based Supabase PKCE, not a native Android OAuth client — see
`docs/GOOGLE_OAUTH_RELEASE_CHECKLIST.md` for the exact console/dashboard
checklist.

## Data safety

See `docs/PLAY_DATA_SAFETY_TECHNICAL_INPUT.md`. Key honest answer today:
**no in-app account/data deletion path exists** — this needs a decision
and either a manual (support-email) or in-app deletion process before
submission, not a fabricated "yes."

## Release signing status

**Not production-ready.** The release build type currently signs with the
Android debug certificate — verified via a real `flutter build
appbundle --release` dry run and `apksigner verify`. See
`docs/ANDROID_RELEASE_ARTIFACTS_RUNBOOK.md` for exactly what to do once a
production keystore exists. `RELEASE_SIGNING=NOT_YET_AUTHORIZED`.

## AAB status

A release AAB builds successfully today (43.0MB, `mapping.txt` generated,
R8/tree-shaking active) — the *pipeline* works. The artifact produced
today is debug-signed and was built without real Supabase configuration
(no `--dart-define-from-file`), so it is a build-mechanics proof only, not
a submittable candidate.

## 16KB native-library page-size compatibility

Verified via `zipalign -c -P 16` on the release APK: **compatible**. No
action needed — the only native libraries packaged are the standard
Flutter engine/runtime libraries.

## Closed-test history

This project has an extensive internal QA history (physical Galaxy A14
certification across many sessions — see `docs/LOOP_FINAL_STATE.md` and
`docs/CLAUDE_FINAL_COMPLETION_RUN.md`), but **no Play Console closed
testing track has ever been used** — that's a distinct thing from local
physical QA, and Play has its own closed-testing requirements (minimum
tester count and duration) before a production release for a new
application, which apply independently of how much local QA has happened.

## What the owner must verify in Play Console (this session cannot)

- Whether a Play Console developer account exists and is in good standing.
- Whether the `com.loop.app.loop_mobile` application ID is available (not
  already registered by someone else, and not previously used and
  released by this same account under different circumstances).
- Play's current closed-testing requirements for a first release (these
  change over time — check Play Console's own current policy, don't rely
  on this document's memory of past requirements).
- Content rating questionnaire — not assessed here; LOOP has no content
  requiring a specific rating as far as this session's code review found,
  but the questionnaire itself must be completed by the account owner in
  Play Console.

## What must NOT be claimed yet

- That the app is signed for production (it isn't).
- That data-safety/deletion questions have real answers beyond what's in
  `docs/PLAY_DATA_SAFETY_TECHNICAL_INPUT.md` today.
- That any Play Console track has ever been used.
- That a privacy policy exists (it doesn't — see
  `docs/TECHNICAL_DATA_INVENTORY.md`, and Play requires a live, hosted
  privacy policy URL for a real listing).
