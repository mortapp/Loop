# Failure-Mode Audit

Updated: 2026-08-25

Reviewed each failure mode against actual code and existing test coverage
rather than re-testing everything from scratch — the 209-case database
suite, 99-case Flutter suite, and web suite already exercise most of these
paths; this audit cross-checks that the coverage is real, not just
counted.

| Failure mode | Behavior | Evidence |
| --- | --- | --- |
| Supabase unavailable / network offline | Fails closed with `userSafeActionError()`/`AsyncErrorView` — never shows fake success, never renders a raw exception | `apps/mobile/lib/core/widgets/async_error_view.dart`; used throughout every repository call site checked this session (Sell, Money, Business, Protect) |
| Storage upload fails | `pickAndUploadPhoto` returns a user-safe error string, never partially links a photo whose upload failed | `apps/mobile/lib/features/sell/sell_providers.dart` |
| Storage deletion fails after DB detach | Rolls back: re-attaches the photo record via `attach_item_photo` if the Storage `remove()` call fails, so the DB and Storage never disagree | `sell_providers.dart`'s `removePhoto` — verified via code read this session |
| Google OAuth canceled | Explicit `cancel()` path and a user-facing "Google sign-in was canceled. You can try again." message, not a stuck spinner | `apps/mobile/lib/core/auth/google_oauth_controller.dart`; covered by `test/core/auth/google_oauth_controller_test.dart` ("handles a Google cancellation stream error without an unhandled error") |
| Google OAuth timeout | A launched flow that never produces a session times out explicitly rather than hanging forever | Same controller; covered by "times out a launched flow that never produces a session" |
| AI provider missing | Both `/api/ai/chat` and `/api/ai/confirm` return a truthful `"AI is not configured (ANTHROPIC_API_KEY unset)."` error, not a fabricated response | `apps/web/src/app/api/ai/{chat,confirm}/route.ts`, verified this session — see `docs/ASK_LOOP_PROVIDER_ENABLEMENT.md` |
| AI provider timeout/error | Mobile's Ask LOOP clears its loading state and remains retryable on any thrown gateway error | `apps/mobile/test/features/ai/ai_account_scope_test.dart` — "unexpected gateway failure clears loading and remains retryable" |
| RPC returns zero rows / RLS denies write | Every validated-write RPC checks account ownership before mutating and raises with a specific errcode (`42501` unauthorized, `23503` not-found/foreign-key, `23514` invalid-state) rather than silently no-op'ing | `supabase/migrations/20260823060632_enforce_atomic_money_lifecycle.sql` and siblings; 209-case suite exercises the hostile-client denial paths |
| Duplicate submit (Money) | Manual Money entries are exactly-once on both web and mobile | `docs/KNOWN_ISSUES.md` "Resolved in the Final Pass"; physically re-verified this session is unnecessary since no Money code changed |
| Duplicate quote acceptance | Exactly one Money event per quote, retry-proof | pgTAP `014_quote_acceptance_money.sql`; physically verified this session (checkpoint 3, `docs/LOOP_FINAL_STATE.md`) — same quote's UI offers no re-accept control once accepted |
| Duplicate sale | `sales_one_per_item_idx` unique index — a second sale for the same item is a database-level conflict, not just an application check | `20260823060632_enforce_atomic_money_lifecycle.sql` |
| Duplicate refund | `returns_refund_state_valid` constraint plus forward-only status transition (`refunded` is terminal) | Same migration; physically verified this session — no re-refund control appears once a return is `refunded` |
| Duplicate AI execution | Unique partial indexes on `actions`/`money_events` keyed by the AI confirmation's `source_id` | `20260823201710_make_ai_confirmations_idempotent.sql`; pgTAP `010_ai_confirmation_idempotency.sql` |
| Account switches mid-async-request | A stale AI proposal from a prior account is invalidated on switch, not silently applied to the new account | `test/features/ai/ai_account_scope_test.dart` — "account switch clears a pending AI confirmation" and "an old account response is ignored after an account switch" |
| App backgrounds/browser navigates mid-write | Not specifically re-tested this session (no runtime change); the underlying RPCs are atomic single-statement transactions, so a killed request either fully applies or fully doesn't — there's no multi-step client-side write sequence for Money/quote/sale/refund left in an inconsistent partial state by design | Migration bodies use single `plpgsql` functions wrapping all related writes in one implicit transaction |

## What was NOT found

No fake-success path, no place where a spinner can end without either a
real result or a real error, no raw SQL error surfaced to a user, and no
duplicate-write path in the flows this session actually walked physically
(Sell, Protect, Business quotes) or the flows already covered by the
209-case suite.

## No runtime changes made

This audit found no new defect. The existing safe-failure patterns were
verified, not modified.
