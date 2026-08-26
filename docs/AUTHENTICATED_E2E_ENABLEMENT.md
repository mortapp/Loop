# Authenticated Playwright E2E Enablement Runbook

Updated: 2026-08-25

## Current state (verified this session)

`apps/web/playwright.config.ts` already implements the correct pattern:

```ts
export const hasQaCredentials = Boolean(process.env.QA_TEST_EMAIL && process.env.QA_TEST_PASSWORD);
```

Every authenticated spec calls `test.skip(!hasQaCredentials, ...)` and
skips truthfully (not silently, not marked as passing) when the two
environment variables are absent. This session ran the full suite:
**31 pass, 60 credential-gated skip, 0 fail** — matching the documented
baseline exactly. No test bypasses the gate or fakes a pass. This harness
does not need engineering work; it needs the credential to exist.

**Never** populate `QA_TEST_EMAIL`/`QA_TEST_PASSWORD` with the owner's own
account (`josephlecctron@gmail.com` or any personal identity) — a CI
secret is readable by anyone with repo write access and appears in
workflow logs on failure paths; it must be a disposable, isolated identity
with no real financial/business data of consequence.

## Creating a dedicated QA identity

1. Sign up a **new** LOOP account through the normal web sign-up flow
   (email + password, not Google — avoids needing a dedicated Google
   account too) using an email address you control but that isn't the
   owner's primary identity — e.g. a `+qa` Gmail alias
   (`youraddress+loopqa@gmail.com`) or a separate mailbox.
2. Complete onboarding normally so the account has a real, completed
   profile (the tests exercise real authenticated journeys — Today,
   Money, Sell, Business, Protect, Ask LOOP, account menu,
   personalization).
3. Do not put anything sensitive in this account — Playwright's specs
   create and read back their own test data as part of each run
   (see `apps/web/e2e/*.spec.ts`), so the account just needs to exist and
   be able to log in.
4. This identity only needs the same permissions any normal signed-up user
   has — no elevated role, no service-role access.

## Populating GitHub Actions secrets

1. Repository → Settings → Secrets and variables → Actions → New
   repository secret.
2. Add `QA_TEST_EMAIL` (the address from step 1) and `QA_TEST_PASSWORD`
   (its password) as two separate secrets.
3. Reference them in the CI workflow's Playwright step as `env:
   QA_TEST_EMAIL: ${{ secrets.QA_TEST_EMAIL }}` /
   `QA_TEST_PASSWORD: ${{ secrets.QA_TEST_PASSWORD }}` — check
   `.github/workflows/` for the exact job name to add this to (Phase 16 of
   this audit reviewed the workflow structure; see
   `docs/CLAUDE_OVERNIGHT_RELEASE_READINESS.md` for that finding).
4. Never echo these secrets in a workflow step (GitHub already masks known
   secret values in logs, but avoid printing them regardless).

## Verifying it works

1. Push a commit (or use `workflow_dispatch`) after the secrets are set.
2. Confirm the Playwright job now reports more than 31 passing tests —
   the previously-skipped 60 should execute. A `0 fail` result with the
   full ~91 tests running is the target; a real assertion failure means a
   genuine defect, not a harness problem, and should be fixed rather than
   converted back to a skip.
3. If a test fails only in CI and not locally, check for environment
   differences (base URL, timing) before assuming a product defect.

## Rotating or disabling the QA identity

- **Rotate the password**: change it through LOOP's own password-reset
  flow, then update the `QA_TEST_PASSWORD` GitHub secret to match.
- **Disable entirely**: remove both GitHub secrets — `hasQaCredentials`
  will go back to `false` and every authenticated test truthfully skips
  again, with zero code changes needed.
- **Retire the identity**: once account deletion exists (see
  `docs/OWNER_RELEASE_ACTION_CENTER.md` — it doesn't yet), delete the QA
  account through it. Until then, simply stop using it and remove the
  secrets; it holds no real user data.

## What this runbook does not do

It does not create the QA account, does not use the owner's personal
Google credentials for CI, and does not commit or print any password.
