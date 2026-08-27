# LOOP — iOS

**Make → Buy → Protect → Recover → Sell → Money → Repeat.**

LOOP is a native iOS app for the whole economic lifecycle of one person's money:
the work they quote and win, the things they buy, the receipts and deadlines that
protect those purchases, the refunds they're owed, the items worth selling again,
and the single ledger every one of those events writes into.

---

## Opening the project

```bash
open LOOP.xcodeproj
```

- Xcode 16 or later
- iOS 18 minimum deployment target
- Swift 6 language mode, `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`
- No third-party dependencies — pure SwiftUI, Swift Concurrency and Foundation

Build and run the `LOOP` scheme on an iPhone simulator. Production configuration is already wired to LOOP's hosted Supabase project using only its public publishable key. Sample services remain available for explicit development/demo use; production does not silently fall back to them.

Run the test suite with `⌘U` (Swift Testing).

---

## The product in five tabs

| Tab | Answers |
| --- | --- |
| **Today** | What needs my attention right now? |
| **Money** | Where is my money going and coming from? |
| **Sell** | What can I turn back into money? |
| **Business** | How do I create and close income? |
| **Ask LOOP** | What does LOOP know that helps me right now? |

Secondary modules — Purchases, Protect, Returns, Refunds, Warranties, Documents,
Leads, Customers, Opportunities, Quotes, Earnings, Search, Profile, Settings,
Personalization, Help — all live behind those five.

---

## Folder structure

```text
LOOP/
├── App/                 Entry point, root flow, environment, router, deep links
├── Core/                Errors, formatters, logging, config, security, networking
├── DesignSystem/        Tokens (colour, type, spacing, motion) and components
├── Domain/              Models + the Today rule engine. No UIKit, no networking.
├── Services/
│   ├── Protocols/       The service contracts every screen depends on
│   └── Live/            Supabase / LOOP-server implementations
├── Development/         Fixtures + sample services. Never used in production.
├── Features/            One folder per feature area, view + view model
└── Assets.xcassets
LOOPTests/               Swift Testing suite over pure logic and flows
docs/                    Architecture, backend integration, handoff, feature matrix
```

Full detail: [`docs/IOS_ARCHITECTURE.md`](docs/IOS_ARCHITECTURE.md).

---

## Architecture in one paragraph

Views depend only on **protocols** (`MoneyService`, `QuoteService`, …) that they
receive from `AppEnvironment` through the SwiftUI environment. `AppEnvironment`
picks its implementations once at launch: live Supabase-backed services when a
backend is configured, clearly-labelled sample services when it isn't. Global
state (`AppState`) holds only session, active account and preferences; every
feature owns its own `@Observable` view model and `LoadState`. Navigation is
strongly typed (`AppDestination`) with one stack per tab, driven by `AppRouter`,
and every URL is parsed in exactly one place (`DeepLinkRouter`).

---

## Environments

`AppEnvironment.resolve()` chooses between two complete sets of services:

- **Live** — `Services/Live`. Talks to Supabase (PostgREST + RPC) and LOOP's own
  API for Ask LOOP. When configuration is missing, live services throw
  `LoopError.serviceUnavailable` and the UI shows a real error state.
- **Sample** — `Development/`. A coherent in-memory account with real
  relationships (a purchase → its return → its refund → its Money transaction).
  Every screen shows a persistent "Sample data" banner so nothing is ever
  presented as a live record.

**Production services never fall back to fixtures.** That rule is the reason the
two trees are separate.

---

## Configuration

Only publishable values live in the client. Read via `LoopConfiguration`:

| Key | Purpose |
| --- | --- |
| `SUPABASE_URL` | Supabase project URL |
| `SUPABASE_ANON_KEY` | Publishable anon key (RLS-protected) |
| `LOOP_API_BASE_URL` | LOOP's own API, which brokers Ask LOOP |

Service-role keys, database passwords and AI-provider credentials are **never**
present in this app. See [`docs/BACKEND_INTEGRATION.md`](docs/BACKEND_INTEGRATION.md).

---

## Deep links

```text
loop://today            loop://purchase/{id}     loop://lead/{id}
loop://money            loop://return/{id}       loop://opportunity/{id}
loop://sell             loop://refund/{id}       loop://quote/{id}
loop://business         loop://warranty/{id}     loop://customer/{id}
loop://ask              loop://item/{id}         loop://transaction/{id}
loop://protect          loop://sale/{id}         loop://search
```

`com.loop.app.loop_mobile://login-callback` is reserved for the Supabase PKCE OAuth redirect. The separate `loop://` scheme remains for ordinary app deep links.

---

## Testing

`LOOPTests` covers the logic that must never drift:

- Decimal money arithmetic, formatting and parsing
- Quote line totals, subtotal, discount floor, tax-after-discount, total
- Sale net proceeds (`gross − fees − shipping`)
- Return-window deadlines, expiry and extension
- Refund overdue rules and warranty status thresholds
- Relative/deadline date phrasing
- Deep-link parsing, including rejection of foreign schemes
- Today rule generation, ordering and stable action identity
- Cross-feature flows: refund settlement, sale completion, earning recording,
  lead conversion, quote acceptance, return advancement
- Error mapping and message safety

---

## What LOOP does not do

LOOP is deliberately honest about its boundaries:

- It does not contact merchants or file returns for you.
- It does not submit refunds — you mark them received when the money lands.
- It does not list items on any marketplace.
- Resale values are **your** estimates, never live market prices.
- Ask LOOP calls LOOP's deployed server API when authenticated. If the server-side AI provider is not configured, the app shows that limitation instead of fabricating an answer.

---

## Remaining external requirements

The backend integration is source-complete, but native certification still requires a Mac with Xcode: build/test the target, run the Google → Supabase → native callback flow, test on an iPhone/simulator, then configure Apple signing only when a release is authorized. Ask LOOP live model output also depends on the server-side provider key being configured; that key never belongs in this client. See [`docs/IOS_SUPABASE_INTEGRATION_STATUS.md`](docs/IOS_SUPABASE_INTEGRATION_STATUS.md).
