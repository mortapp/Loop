# LOOP Codex Primary Finishing Progress

Updated: 2026-08-23T21:35:00Z

## Repository

- Repository: `C:\Users\micha\OneDrive\Desktop\Loop`
- Branch: `main`
- Tested runtime checkpoint: `6c908668b6ef50ef1499e48f2270d8484dd4ae14`
- Remote: `git@github.com:mortapp/Loop.git`
- Source version: `1.0.0+1`
- Android package: `com.loop.app.loop_mobile`
- Hosted Supabase: `zqalnvfwxmfrnyjcuehq`
- Production web: `https://loop-teal-rho.vercel.app`
- MORT: reference-only and unmodified

## Completed Engineering

- Native Google OAuth uses the standards-valid callback
  `com.loop.app.loop-mobile://app/login-callback`. The owner physically
  confirmed Google login reaches authenticated native LOOP on the Galaxy A14.
- Authentication, post-auth profile gating, display name, username, password
  setup, session restoration, cancellation, and onboarding race handling have
  focused regression coverage.
- All six independently reported High findings were repaired: cross-account AI
  confirmation reuse, AI duplicate execution, malformed quote prices, Money
  history truncation, concurrent item-photo metadata loss, and the dead mobile
  business CTA.
- A seventh High found in the final parity audit was repaired: malformed or
  throwing Ask LOOP gateway responses can no longer leave the mobile composer
  permanently busy.
- AI confirmations bind user, account, tool, canonical input, expiration, and a
  stable idempotency identity. Database uniqueness makes approved retries
  exactly-once.
- Purchases, listings, sales, refunds, quote creation, item-photo metadata, and
  Money totals use canonical server-side RPCs and constraints.
- Mobile Money history now uses deterministic 50-row pagination with
  account-switch and stale-request protection.
- The mobile business entry point creates a real business and selects its
  trigger-provisioned business account. It no longer advertises an unavailable
  invitation flow.
- CI is consolidated in `.github/workflows/quality.yml`. It pins Flutter and
  Supabase CLI versions, replays the database from zero, runs pgTAP, web checks,
  Playwright, Flutter checks, and builds a fail-closed debug APK.
- A clean-checkout CI failure exposed a hidden dependency on Next-generated
  `LayoutProps`; the root layout now uses an explicit React prop type.
- Icon-only account and quote-line actions now expose accessible names and
  focused widget tests enforce those semantics.

## Verification

- Local database reset: all 24 migrations and seed applied successfully.
- Database tests: 11 files, 185 assertions, all pass.
- Flutter format: 83 files, 0 changes.
- Flutter analyze: no issues.
- Flutter tests: 87/87 pass serially.
- Focused Ask LOOP failure tests: 11/11 pass.
- Web typecheck, ESLint, and optimized build: pass.
- Playwright: 89 discovered, 29 pass, 60 authenticated tests skip without a
  dedicated QA account, 0 fail.
- GitHub Quality run `32673029762`: PASS on checkpoint `6c90866`; both
  `Flutter mobile` and `Web and database` jobs completed successfully.
- Hosted migration ledger matches the 24 local migration files through
  `20260823202606_make_item_photo_updates_atomic`.
- Production Vercel deployment `6053890989` for runtime checkpoint `6c90866` succeeded.
  The canonical sign-in page renders with no captured browser console errors.
- Tracked-source secret scan found no privileged credentials. The only tracked
  environment files are empty templates with a public site URL default.

## QA APK

- Source commit: `6c908668b6ef50ef1499e48f2270d8484dd4ae14`
- Path:
  `artifacts/final-head-6c90866/loop-6c90866-final-head-configured-debug-qa.apk`
- Size: 157,674,984 bytes (150.37 MiB)
- SHA-256: `57FC377A9AF83F7A574AD11D89A09EDE370E58433BCE15F474F71D61473980B4`
- Package/version: `com.loop.app.loop_mobile`, `1.0.0+1`
- Signing: Android debug certificate, APK Signature Scheme v2 verified
- Configuration: approved public Supabase URL and client-safe key only; no
  service role, provider secret, access token, or private key value.

## Current External Gates

- Wireless ADB currently lists no authorized device, so the exact final QA APK
  has not been installed or run on the Galaxy A14.
- The authenticated Galaxy Today/Money/Sell/Business/Protect/Ask LOOP/account
  gauntlet and final sign-out/sign-in regression remain physical-device work.
- `ANTHROPIC_API_KEY` is not available, so no live provider call was fabricated.
- Authenticated Playwright needs a dedicated non-owner QA account and CI secrets.
- Supabase leaked-password protection is a Free-plan limitation; see
  `docs/KNOWN_ISSUES.md`.
- Native iOS build, signing, TestFlight, and iPhone QA require macOS/Xcode and
  Apple credentials.

## Current Phase

`FINAL VERIFICATION - external physical/provider gates only`
