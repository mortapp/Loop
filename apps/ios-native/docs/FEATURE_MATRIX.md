# Native iOS Feature Matrix

Updated: 2026-08-26

Status here means source integration status for this SwiftUI target. A macOS/Xcode build and physical iOS pass are still required before any row can be called App Store or device certified.

| Surface | SwiftUI UI | Hosted Supabase wiring | Authority / notes | Status |
| --- | --- | --- | --- | --- |
| Auth + session restore | Yes | Yes | Browser Supabase PKCE, `com.loop.app.loop_mobile://login-callback` | Source-wired |
| Required profile onboarding | Yes | Yes | `profiles`, username RPC, Supabase Auth password update | Source-wired |
| Today | Yes | Yes | `generate_today_actions` + `actions` | Source-wired |
| Money | Yes | Yes | `money_events` + `account_money_totals` | Source-wired |
| Purchases | Yes | Yes | `purchases` + linked `items` | Source-wired |
| Returns/refunds | Yes | Yes | `returns`; refund settlement through `refund_return_with_money_event` | Source-wired |
| Warranties | Yes | Yes | `warranties` | Source-wired |
| Documents | Yes | Yes | `documents` + private signed URLs | Source-wired |
| Owned items / Sell | Yes | Yes | `items`, `valuations`, `listings`, `sales` | Source-wired |
| Listing creation | Yes | Yes | `create_listing_and_mark_item` | Source-wired |
| Mark sold | Yes | Yes | `record_item_sale` | Source-wired |
| Leads | Yes | Yes | `leads` + `contacts` | Source-wired |
| Opportunities | Yes | Yes | `opportunities` | Source-wired |
| Quotes | Yes | Yes | `quotes`, `quote_line_items`, atomic quote RPC | Source-wired |
| Quote status | Yes | Yes | `set_quote_status_with_money_event`; exactly-once accepted earn event stays server-owned | Source-wired |
| Customers UX | Yes | Yes | Maps to canonical `contacts`, not a duplicate table | Source-wired |
| Search | Yes | Yes | Real `items`, `opportunities`, `quotes`; no fake search RPC | Source-wired |
| Ask LOOP | Yes | Yes | Same deployed `/api/ai/chat`; mutation confirmation remains server-gated | Source-wired; provider availability external |
| Private Storage | Reader paths | Yes | `documents` signed URLs; `item-photos` remains canonical bucket | Partial native surface |
| Native iOS compile | — | — | Requires macOS + Xcode | Not verified here |
| Physical iPhone QA | — | — | Requires an iOS device/simulator on macOS | Not verified here |
| Release signing / App Store | — | — | Requires Apple signing + explicit release authorization | Not attempted |
