# LOOP Native iOS — Backend Integration

Updated: 2026-08-26

This native SwiftUI client is wired to the same hosted LOOP backend used by the existing web and Flutter clients. It does **not** introduce a parallel database, duplicate schema, or privileged client secret.

## Production endpoints

- Supabase project: `zqalnvfwxmfrnyjcuehq`
- Supabase URL: `https://zqalnvfwxmfrnyjcuehq.supabase.co`
- Client credential: Supabase **publishable** key only
- LOOP server API: `https://loop-teal-rho.vercel.app/api`
- Native OAuth callback: `com.loop.app.loop_mobile://login-callback`

The publishable key is intentionally client-visible. Authorization is enforced by Supabase Auth, Row Level Security, account-scoped policies, and server-authoritative RPCs. Never add a service-role key, database password, Google client secret, Anthropic key, signing key, or other privileged credential to the iOS target.

## Authentication

The iOS app follows LOOP's existing browser-based Supabase PKCE architecture:

1. Generate a PKCE verifier/challenge locally.
2. Open Supabase Auth for Google in the system browser.
3. Receive `com.loop.app.loop_mobile://login-callback`.
4. Reject token-bearing callback query/fragment values.
5. Exchange the authorization code + verifier with Supabase.
6. Keep the resulting session in the app's secure session store and refresh through Supabase Auth.

This is deliberately not a separate native Google SDK login system.

## Canonical public data surfaces

The native services use the current hosted schema, including:

| Area | Canonical backend records |
| --- | --- |
| Identity/account | `profiles`, `accounts`, `businesses`, `business_members` |
| Today | `actions` |
| Money | `money_events` |
| Protect | `purchases`, `returns`, `warranties`, `documents` |
| Sell | `items`, `valuations`, `listings`, `sales` |
| Business | `contacts`, `leads`, `opportunities`, `quotes`, `quote_line_items` |

The native UX may call a contact a “customer,” but it persists in `contacts`; there is no separate `customers` table. Likewise, refunds are represented by refunded rows in `returns` plus the canonical `money_events` entry; there is no standalone `refunds` ledger table.

## Server-authoritative RPCs used by iOS

| RPC | Native use |
| --- | --- |
| `generate_today_actions(p_account_id)` | Idempotently materialize factual Today actions |
| `account_money_totals(p_account_id)` | Canonical Made / Protected / Recovered / spent / fees / net totals |
| `create_quote_with_line_items(...)` | Atomic quote + line-item creation with server validation |
| `set_quote_status_with_money_event(p_quote_id, p_status)` | Quote lifecycle; accepting creates the exactly-once earn event |
| `create_listing_and_mark_item(...)` | Atomic listing creation + item lifecycle transition |
| `record_item_sale(...)` | Atomic sale + item/listing transition + recovered/fee Money events |
| `refund_return_with_money_event(...)` | Atomic refunded return + ownership transition + refund Money event |
| `is_username_available(candidate)` | Onboarding availability pre-check; DB constraint remains authoritative |

The client does not recreate these financial/lifecycle invariants locally with multi-step writes.

## Storage

LOOP currently uses private Supabase Storage buckets:

- `documents`
- `item-photos`

The native document reader requests short-lived signed URLs from Supabase Storage. Client code must never turn these buckets public or persist a signed URL as permanent record data.

## Ask LOOP

Provider secrets remain server-side. The native app calls the same deployed endpoints as other LOOP clients:

- `POST /api/ai/chat`
- `POST /api/ai/confirm` (confirmation-capable server contract)

The app sends the user's Supabase bearer session and active account ID. If the server reports that the model provider is not configured, iOS surfaces that state honestly. It never embeds `ANTHROPIC_API_KEY` and never auto-approves a mutation.

## What this integration intentionally does not do

- No hosted schema reset or destructive migration.
- No service-role key in Swift.
- No client-side bypass of RLS.
- No fake marketplace publication.
- No fake AI response.
- No direct quote acceptance write that bypasses the authoritative RPC.
- No synthetic refund/sale Money event that can double-count the ledger.
- No claim that the iOS binary has been built or device-tested until Xcode/macOS verification actually occurs.
