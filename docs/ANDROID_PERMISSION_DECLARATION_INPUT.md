# Android Permission Declaration — Technical Input

Updated: 2026-08-25

Built from the actual merged manifest of the built release APK (verified
this session via `apkanalyzer manifest permissions` and
`apkanalyzer manifest print` — see `docs/ANDROID_RELEASE_ARTIFACTS_RUNBOOK.md`),
not from source assumptions.

## Permissions actually present in the shipped app

| Permission | Feature | User action that triggers it | Core functionality? | Play disclosure likely needed? |
| --- | --- | --- | --- | --- |
| `android.permission.INTERNET` | All network access — Supabase auth/data/Storage, Ask LOOP backend calls | Using the app at all | Yes — the entire app is a synced, backend-driven product | Standard; INTERNET is not a Play-disclosed "dangerous" permission |
| `com.loop.app.loop_mobile.DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION` | Auto-generated, self-signature-scoped permission for AndroidX's dynamic-broadcast-receiver registration (`Context.registerReceiver` with `RECEIVER_NOT_EXPORTED` on Android 13+) | Not user-facing; internal AndroidX/library plumbing | N/A | No — not a user-visible or third-party-exploitable permission; nothing to disclose |

**That's the complete list.** No camera, storage, photos/media, location,
microphone, contacts, calendar, SMS, call log, body sensors, advertising
ID, notifications, or background-location permission is requested by this
build. Modern `image_picker` uses the system Photo Picker on this
project's target SDKs, which doesn't require a manifest permission grant
at all.

## Why this matters for release

A near-empty permission footprint is a genuine asset for Play review and
user trust — there is no minimization work to do here, and no permission
declaration to justify beyond "the app needs internet access to sync your
ledger," which is self-evident for a cloud-backed product.

## If a future feature adds a permission

Update this document in the same change that adds the permission,
following the same table format: which permission, which feature, whether
it's install-time or runtime-requested, and whether it's optional to the
feature it supports (e.g. camera access for item photos could later be
requested at runtime if the app adds native camera capture instead of
relying on the system picker — that would be a deliberate product decision,
not something to add speculatively).
