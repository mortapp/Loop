# Ask LOOP Provider Enablement Runbook

Updated: 2026-08-25

## Current state (verified this session)

`ANTHROPIC_API_KEY` is read in exactly three server-only places, all under
`apps/web/src/`:

- `lib/ai/client.ts` — `isAiConfigured()` checks it's set; `getClient()`
  constructs the Anthropic SDK client with it, and throws if called
  without checking `isAiConfigured()` first.
- `lib/ai/confirmation-token.ts` — used as the HMAC signing key for
  tool-confirmation tokens (the mechanism that makes a proposed AI action
  tamper-evident and bindable to a specific account/user/tool/input before
  the user confirms it).
- `app/api/ai/chat/route.ts` and `app/api/ai/confirm/route.ts` — the two
  Next.js Route Handlers (server-only; never bundled to the browser) that
  the chat UI and mobile's Ask LOOP screen both call. Both routes return a
  truthful `"AI is not configured (ANTHROPIC_API_KEY unset)."` error today
  instead of a fake response.

Grepped the entire mobile app: **no client ever references
`ANTHROPIC_API_KEY` or calls Anthropic directly.** Mobile's
`lib/features/ai/ai_repository.dart` calls `/api/ai/chat` and
`/api/ai/confirm` on the web deployment over plain HTTP(S) — the API key
never leaves the server.

## Exactly what to configure

1. **Where it belongs**: the Vercel project's **Production** (and
   Preview, if you want AI in preview deployments) **Environment
   Variables**, as a plain (not `NEXT_PUBLIC_`-prefixed) variable named
   `ANTHROPIC_API_KEY`. Never prefix it `NEXT_PUBLIC_` — that prefix tells
   Next.js to bundle the value into client-side JavaScript, which would
   ship your API key to every browser that loads the page.
2. **Where it must NOT exist**: `apps/mobile/dart_define.json` (mobile
   never needs it — it calls the web API, not Anthropic), any committed
   file, any `NEXT_PUBLIC_*` variable, any client-side code path, or a
   GitHub Actions secret unless a CI job specifically needs to call the
   live provider (it currently doesn't — CI tests use a
   self-labeled `"test-only-confirmation-signing-key"` placeholder value
   in `apps/web/e2e/ai-confirmation-token.spec.ts`, not a real key).
3. **How to configure securely**: Vercel Dashboard → Project → Settings →
   Environment Variables → Add. Paste the real key value there directly;
   never put it in a file this session (or any future session) reads or
   writes.
4. **How to redeploy**: Vercel environment variable changes take effect on
   the *next* deployment — either push a new commit, or use Vercel's
   "Redeploy" action on the existing production deployment.

## Verifying it's live

1. **Read-only config check**: hit `/api/ai/chat` or `/api/ai/confirm`
   with a request that would previously have returned the "AI is not
   configured" error (e.g. through the Ask LOOP UI) and confirm you now
   get a real model response instead.
2. **Harmless smoke test**: from Ask LOOP (web or mobile), ask a
   read-only question that shouldn't propose any mutation (e.g. "What's
   my current Money total?") and confirm a real, sensible answer comes
   back — not a fabricated one you can't verify, and not a raw provider
   error leaking implementation details.
3. **Test a proposal**: ask something that should propose a mutation
   (e.g. "log a $5 manual entry") and confirm you get a proposal/
   confirmation step, not an immediate silent write.
4. **Test Decline**: decline the proposal and confirm nothing was written
   (check Money/Today afterward).
5. **Test Confirm**: confirm a proposal and verify exactly one mutation
   happened — check the resulting Money event or action once, not twice.
6. **Test retry idempotency**: replay the exact same confirmation request
   (same confirmation token) a second time and confirm it does **not**
   duplicate the mutation — this exact guarantee is covered by
   `supabase/tests/database/010_ai_confirmation_idempotency.sql` in the
   209-case suite, so a live-provider retry should behave identically.
7. **Test account-switch invalidation**: start a proposal on one account,
   switch active accounts, and confirm the stale proposal is rejected
   rather than silently applied to the new account — covered by
   `apps/mobile/test/features/ai/ai_account_scope_test.dart` and the
   equivalent server-side binding.

## How to disable immediately if needed

Remove or blank the `ANTHROPIC_API_KEY` environment variable in Vercel and
redeploy (or use Vercel's instant rollback to the prior deployment). The
routes already fail closed with a truthful "not configured" message rather
than a fake response or a stack trace — no code change is needed to turn
it back off.

## What this runbook does not do

It does not create, request, or embed a real Anthropic API key anywhere.
No file in this repository or any artifact from this session contains one.
