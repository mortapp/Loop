# LOOP Final External-Gate Handoff

Updated: 2026-08-23

No unresolved Critical or High code-controlled finding is being handed off.
Do not create cleanup work merely to continue activity. Resume engineering only
when one of these external gates changes or new evidence reveals a defect.

## Tested Checkpoint

- Branch: `main`
- Source/workflow checkpoint: `03d6c5412be85beadbaf458aa922b3be2bdce97b`
- Supabase: `zqalnvfwxmfrnyjcuehq`
- Production web: `https://loop-teal-rho.vercel.app`
- Android package/version: `com.loop.app.loop_mobile`, `1.0.0+1`
- Callback: `com.loop.app.loop-mobile://app/login-callback`
- Database: 24 migrations, 185/185 tests
- Flutter: 85/85 tests
- Playwright: 29 pass, 60 credential-gated skips, 0 fail
- GitHub Quality run: `32667680943`, PASS

## Resume Conditions

### Galaxy A14 reconnects

Run `adb devices -l` and use the current wireless serial. Do not clear data or
sign the owner out first. Install the exact configured APK from
`artifacts/final-qa-58e3b8e`, preserve the session, and run Today, Money, Sell,
photo picker, Business, quotes, Protect, Ask LOOP, account switching,
background/resume, and sanitized logcat. Sign out only at the end, then verify
Google returning-user login routes to Today without onboarding.

### Dedicated QA credentials exist

Set `QA_TEST_EMAIL` and `QA_TEST_PASSWORD` only in the secure CI environment and
run the existing Playwright suite. Do not commit or report values. Repair any
real authenticated assertion failure; do not convert it to a skip.

### Anthropic is configured

Set `ANTHROPIC_API_KEY` server-side only. Run one controlled Ask LOOP response,
proposal, decline, confirm, account-switch rejection, and duplicate-confirm
retry. Verify one database mutation and no secret/provider error disclosure.

### macOS/Xcode is available

Run dependency install, Xcode build, simulator checks, real iPhone auth/deep
link/photo behavior, signing, and TestFlight. Windows static parity is not a
substitute.

### Supabase plan becomes Pro

Enable leaked-password protection immediately and rerun Auth security advisors.

## Release Boundary

Do not auto-publish. A release decision still needs exact final signed
artifacts, physical-device evidence, privacy/legal/product approval, and the
remaining provider gates documented above.
