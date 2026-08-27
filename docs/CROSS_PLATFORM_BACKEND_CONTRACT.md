# Cross-Platform Backend Contract

The PostgreSQL schema, RLS policies, constraints, triggers, and authenticated RPCs in `supabase/migrations` are LOOP's authority. Web, Flutter, and native SwiftUI are safe request/presentation clients of the same Supabase project: `zqalnvfwxmfrnyjcuehq`.

| Domain | Canonical tables / storage | Authoritative write path | Client parity |
| --- | --- | --- | --- |
| Identity and profile | `profiles`, Supabase Auth | Auth bootstrap, profile policies, username RPC | Web, Flutter, and SwiftUI use the same Auth identity and account bootstrap. |
| Accounts | `accounts`, `businesses`, `business_members` | RLS-backed account membership rules | All clients scope records by the active account; server RLS remains decisive. |
| Today | `actions` | `generate_today_actions(p_account_id)` | Web/Flutter and SwiftUI read server-generated actions. |
| Money | `money_events` | `account_money_totals(p_account_id)` plus lifecycle RPCs | Integer-cent values only; client totals are presentation, not authority. |
| Purchases | `purchases`, `items` | `create_purchase_with_money_event` | Flutter and SwiftUI call the canonical purchase RPC; web calls the same RPC server-side. |
| Returns and refunds | `returns`, `items`, `money_events` | guarded status transitions; `refund_return_with_money_event` | Refund is atomic and idempotent at the server. |
| Warranties | `warranties` | RLS-backed write policies and lifecycle constraints | Shared account-scoped reads and writes. |
| Items and valuations | `items`, `valuations` | item constraints; append-only valuation policy | Clients use real item/valuation tables, not legacy inventory aliases. |
| Listings and sales | `listings`, `sales`, `items`, `money_events` | `create_listing_and_mark_item`, `record_item_sale` | Listing eligibility and sales ledger effects are server enforced. |
| Business | `contacts`, `leads`, `opportunities` | account-scoped RLS and foreign-key integrity | SwiftUI search routes contacts and leads to the same canonical business records. |
| Quotes | `quotes`, `quote_line_items`, `money_events` | `create_quote_with_line_items`, `set_quote_status_with_money_event` | Multi-line totals and acceptance money effects are server authoritative. |
| Documents | `documents`, private `documents` Storage bucket | RLS metadata plus time-limited signed URLs | Every client treats object access as private/account-scoped. |
| Item photos | `items`, private `item-photos` Storage bucket | `attach_item_photo`, `detach_item_photo` | Paths and metadata updates remain account/item scoped in SQL. |
| Ask LOOP | deployed LOOP server API | authenticated server routes and confirmation controls | No client contains an Anthropic/provider secret; clients send authenticated requests only. |

## Authentication callback

The existing browser PKCE callback is `com.loop.app.loop_mobile://login-callback`. It is shared by the mobile clients and intentionally differs from the native iOS bundle identifier, `com.loop.app.loop_ios`.

## Stale-contract rule

Clients must not introduce `money_transactions`, `owned_items`, `inventory_items`, `loop_exchange_oauth_code`, a parallel Supabase project, or compatibility tables. A mismatch is repaired in the client adapter unless a new, forward-migrated backend requirement is demonstrated.
