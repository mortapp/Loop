# LOOP Known Issues and External Gates

Updated: 2026-08-23

## Open External Gates

### Final authenticated Galaxy A14 gauntlet

The owner has physically confirmed that native Google login works and reaches
authenticated LOOP. The working callback is
`com.loop.app.loop-mobile://app/login-callback` and must not be changed.

Wireless `adb devices -l` currently returns no authorized device. The final
configured APK therefore has not been installed or traversed. Do not mark the
following complete until the exact APK is tested without clearing the owner's
session: Today, Money, Sell/photo picker, Business/quotes, Protect, Ask LOOP,
account switching, background/resume, logcat, sign-out last, then Google
returning-user sign-in.

### Live AI provider

`ANTHROPIC_API_KEY` is unavailable locally. The authorization, confirmation,
account binding, tamper resistance, expiration, and exactly-once database path
are implemented and tested. A live model response has not been fabricated.
Configure the key server-side only, then run one controlled provider call and
the authenticated Ask LOOP device/web journeys.

### Authenticated Playwright

The suite discovers 89 tests. Twenty-nine public/guard tests pass and 60 real
authenticated tests intentionally skip when `QA_TEST_EMAIL` and
`QA_TEST_PASSWORD` are absent. Create a dedicated, non-owner QA Supabase user
and store those values as GitHub Actions secrets. Never use the owner's primary
credentials in CI.

### Native iOS

Shared Flutter source and iOS configuration pass static parity review. A real
Xcode build, Apple signing, TestFlight, and iPhone QA require macOS/Xcode and
Apple credentials. No Windows result substitutes for those gates.

### Manual accessibility and release review

Automated public axe coverage, Flutter semantics-focused tests, large-text
auth/onboarding tests, touch-target checks, and Samsung layout tests pass.
Authenticated screen-reader and keyboard journeys still need manual QA on the
final device builds. Release also needs product, privacy, legal, and operational
approval; this document does not provide those approvals.

## Deferred - Plan-Limited Security Enhancement

Supabase leaked-password protection cannot be enabled on the Free plan. This is
not an unresolved code security bug.

Current mitigations:

- strong password minimum length
- required password complexity in the clients
- Auth rate limiting
- email verification policy
- RLS and account graph restrictions
- secure password reset flow

Future task: **When Supabase is upgraded to Pro, enable leaked-password
protection immediately and rerun Auth security advisors.** Do not upgrade or
spend money solely from this task.

## Advisor Findings Accepted With Evidence

- Five authenticated-executable `SECURITY DEFINER` helpers remain:
  `has_account_access`, `is_active_business_member`, `is_business_admin`,
  `is_username_available`, and `shares_active_business`. They are narrow,
  authenticated, search-path-hardened recursion breakers or boolean UX helpers
  used by RLS. Anonymous/PUBLIC execution is revoked. Their authorization
  behavior is covered by the 185-case database suite. Do not revoke them without
  redesigning and retesting the policies that depend on them.
- Performance advisor notices are unused-index INFO entries on a low-traffic
  dataset. The indexes support known relationship, status, deadline, feed, and
  pagination queries. Reassess with production telemetry; do not drop them now.

## Resolved in the Final Pass

- AI proposals cannot survive an account switch or execute under a different
  user/account/tool/input.
- AI confirmation retries are exactly-once at the database boundary.
- Malformed Ask LOOP payloads and thrown gateway calls fail closed and clear the
  mobile loading state.
- Malformed, blank, non-finite, and negative quote prices are rejected; explicit
  zero remains valid.
- Money history is paginated rather than silently capped at 200 events.
- Item-photo attach/detach is atomic and no longer overwrites concurrent paths.
- Mobile business creation is real; the dead join/create card is gone.
- Clean-checkout web typecheck no longer depends on generated Next globals.
- CI is one authoritative workflow rather than three overlapping workflows.

## Security Hygiene

No service role, Supabase access token, database password, Anthropic secret,
Google client secret, GitHub token, private key value, QA password, or ignored
`dart_define.json` is tracked. Public Supabase URL/client configuration remains
client-safe by design; privileged configuration stays server-side.
