# LOOP Known Issues and External Gates

Updated: 2026-08-24

## Open External Gates

### Remaining Ledger 2.0 physical gaps

The Galaxy A14 physical run is complete for the core authenticated journey.
The repaired configured APK is
`artifacts/ledger-2-385a787/loop-ledger-2-385a787-configured-debug-qa.apk`
(SHA-256 `967ABD5BC393EE160E50AE5FCDD0A91193C51B3C5B6196939FDF22795A6D7A1A`).
Google returning-user login returned through the native callback directly to
Today without onboarding or a Vercel page. Current-process logcat was clean.

Remaining gaps are narrower: Sell Copy/Share/Export controls are absent; an
invalid listing action is still shown for returned/disposed items even though
the server rejects it; multiple-line quote creation and a real alternate-account
switch were not completed physically; and no valid Flutter frame-timing profile
was captured. These are not represented as passed.

### Live AI provider

`ANTHROPIC_API_KEY` is unavailable locally. The authorization, confirmation,
account binding, tamper resistance, expiration, and exactly-once database path
are implemented and tested. A live model response has not been fabricated.
Configure the key server-side only, then run one controlled provider call and
the authenticated Ask LOOP device/web journeys.

### Authenticated Playwright

The suite discovers 91 tests. Thirty-one public/guard tests pass and 60 real
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

- Seven authenticated-executable `SECURITY DEFINER` functions remain:
  `create_quote_with_line_items`, `has_account_access`,
  `is_active_business_member`, `is_business_admin`,
  `is_username_available`, `set_quote_status_with_money_event`, and
  `shares_active_business`. The quote functions are
  the narrow validated write authority after direct quote creation and line
  mutation were revoked, and accepted status atomically writes one Money event.
  The others are search-path-hardened recursion breakers or boolean helpers used
  by RLS. Anonymous/PUBLIC execution is revoked. Their authorization behavior is
  covered by the 209-case database suite.
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
- Icon-only account and quote-line controls now expose accessible names, with
  focused widget regression coverage.
- Fractional-cent, exponent, unsafe, and oversized money values are rejected
  consistently by web, Flutter, AI tool input, and Postgres constraints.
- Manual Money retries are exactly-once on web and mobile.
- Direct quote total, header, line, and delete mutations are denied; quote
  creation remains available only through its validated server function.

## Security Hygiene

No service role, Supabase access token, database password, Anthropic secret,
Google client secret, GitHub token, private key value, QA password, or ignored
`dart_define.json` is tracked. Public Supabase URL/client configuration remains
client-safe by design; privileged configuration stays server-side.
