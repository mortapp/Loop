# LOOP iOS architecture

## Principles

1. **One ledger.** Money is canonical. Business, Sell and Protect never keep
   their own balances — they write transactions into Money.
2. **Views depend on protocols, never implementations.** Swapping sample for
   Supabase changes one function (`AppEnvironment.resolve()`).
3. **Domain logic is pure.** Everything in `Domain/` is `nonisolated`, has no
   UIKit or networking dependency, and is directly unit-testable.
4. **Global state is small.** `AppState` holds session, active account and
   preferences. Nothing else.
5. **Fixtures are quarantined.** `Development/` is the only place sample data
   exists, and its presence is always visible to the user.

---

## Layers

```text
Features (SwiftUI views + @Observable view models)
        │  depends on protocols only
        ▼
Services/Protocols  ──────────────► Services/Live      (Supabase / LOOP API)
        │                     └──► Development/…       (sample, dev only)
        ▼
Domain (models, rules)  ◄── Core (money, dates, errors, logging, security)
        ▲
DesignSystem (tokens + components)
```

### App

| File | Responsibility |
| --- | --- |
| `LOOPApp.swift` | Scene, environment injection, `onOpenURL` |
| `RootView.swift` | Launch → signed out → onboarding → shell → failure |
| `AppState.swift` | Authentication state machine, active account, preferences |
| `AppEnvironment.swift` | Dependency container + environment selection |
| `AppRouter.swift` | Selected tab, one `[AppDestination]` path per tab, sheets |
| `AppDestination.swift` | `LoopTab`, typed destinations, typed sheets |
| `DeepLinkRouter.swift` | The only URL parser in the app |
| `MainTabView.swift` | Tab shell, `DestinationView`, `SheetView`, screen scaffold |

### Authentication state machine

```swift
enum AuthenticationState {
    case checkingSession        // launch, restoring keychain session
    case signedOut              // SignInView
    case authenticating         // browser OAuth leg in flight
    case bootstrappingAccount   // profile + accounts loading
    case onboarding(LoopProfile)
    case signedIn(LoopProfile)
    case failed(LoopError)
}
```

The authenticated shell is never shown until bootstrap reaches `.signedIn`.

### Navigation

- One `NavigationStack` per tab, bound to `router.path(for:)`.
- Re-tapping the active tab pops that stack to root.
- `router.open(_ source: ActionSource)` switches to the record's owning tab and
  pushes it — this is how Today actions and Ask LOOP references navigate.
- Sheets are enumerated in `AppSheet` and presented in one place.

---

## Domain

| Area | Types |
| --- | --- |
| Account | `LoopUser`, `LoopAccount`, `LoopProfile`, `LoopSession` |
| Today | `LoopAction`, `ActionPriority`, `ActionSource`, `TodayDigest`, `LoopContext` |
| Money | `MoneyTransaction`, `MoneySummary`, `MoneyFilter`, `RelatedRecordReference` |
| Purchases | `Purchase`, `OwnedItem`, `ReturnWindow` |
| Protection | `ReturnRecord`, `Refund`, `Warranty` |
| Documents | `LoopDocument`, `DocumentType`, `DocumentAttachmentTarget` |
| Resale | `SaleRecord`, `ResaleCandidate`, `ResaleSummary` |
| Business | `Customer`, `Lead`, `Opportunity`, `Quote`, `QuoteLineItem`, `BusinessEarning` |
| Ask LOOP | `AskLoopMessage`, `AskLoopReference`, `AskLoopResponse` |

### Relationships

```text
Account
├── Money ── transactions ──┐
├── Purchases                │
│   └── OwnedItem            │
│       ├── Documents        │
│       ├── ReturnRecord ── Refund ──────► transaction
│       ├── Warranty         │
│       └── SaleRecord ──────────────────► transaction
└── Business
    ├── Customer ── Lead ── Opportunity ── Quote
    └── BusinessEarning ───────────────────► transaction
```

Every arrow into Money is one `MoneyTransaction` with a
`RelatedRecordReference` pointing back, so navigation works in both directions.

### The Today rule engine

`ActionRule` is a pure function of `LoopContext`:

```swift
protocol ActionRule: Sendable {
    var identifier: String { get }
    func generateActions(from context: LoopContext) -> [LoopAction]
}
```

Eleven rules ship today: return deadlines, pending refunds, overdue refunds,
refunds received, missing receipts, warranty expiry, resale opportunities, sale
follow-ups, lead follow-ups, quote follow-ups/expiry, opportunity attention and
earnings recorded.

Action IDs are **deterministic** (`UUID.deterministic(from:)` over
`rule|recordID`), so completion survives refreshes and list animations stay
stable. `TodayRuleEngine.digest(from:completedActionIDs:)` groups them into the
four Today sections plus recently completed.

The whole engine is replaceable by server-generated actions: `LiveTodayService`
uses `generate_today_actions` plus the canonical `actions` records to return the same `TodayDigest`.

---

## Money precision

- `MoneyAmount` wraps `Decimal` + currency code. No `Double` anywhere in money
  arithmetic.
- `MoneyFormatter` is the only place currency strings are produced, including
  `accessibleString` for VoiceOver ("plus 86 dollars and 42 cents").
- `MoneyFormatter.rounded(_:scale:)` uses `NSDecimalRound` with plain rounding.
- Quote maths: `subtotal → discountedSubtotal (floored at 0) → tax → total`.
- Sale maths: `netProceeds = gross − fees − shipping`.

---

## Design system

`DesignSystem/Theme/LoopTheme.swift` holds every token:

- **Colour** — warm ledger canvas (`#F7F4EE` / `#111013`), ink, hairline, and a
  single vermilion signal accent (`#D8482A` / `#F2643F`) plus positive, caution,
  critical and info semantics. All adaptive light/dark, built in code so the
  palette can be reviewed in one file.
- **Type** — New York (serif) for display moments, SF for UI, rounded
  monospaced digits for every amount.
- **Spacing / radius / motion / icon size** — small, named scales.

Components: `LoopCard`, `LoopCardButton`, `LoopMetricCard`, `LoopButton`,
`LoopSecondaryButton`, `LoopDestructiveButton`, `LoopIconButton`,
`LoopInlineAction`, `LoopStatusBadge`, `LoopPriorityBadge`, `LoopDeadlineView`,
`LoopGlyph`, `LoopMoneyText`, `LoopSectionHeader`, `LoopEyebrow`,
`LoopDetailRow`, `LoopListRow`, `LoopDivider`, `LoopTextField`,
`LoopCurrencyField`, `LoopTextEditor`, `LoopFilterChips`, `LoopTimeline`,
`LoopEmptyState`, `LoopErrorState`, `LoopSkeleton`, `LoopLoadingState`,
`LoopSheetHeader`, `LoopEditorScaffold`, `LoopDetailSection`, `LoopRowGroup`,
`DocumentRow`, `LoopMark`.

### State rendering

Every async feature uses `LoadState<Value>` and renders it through
`LoadableView`: loading skeleton → loaded → error with retry, plus an
intentional empty state written per list.

---

## Accessibility

- Dynamic Type throughout; amounts use `minimumScaleFactor` rather than
  truncation.
- Status is never colour-only — every badge carries a glyph and a label.
- Money reads correctly under VoiceOver via `MoneyFormatter.accessibleString`.
- Minimum 44×44pt targets on all controls, including inline actions.
- Cards combine into single accessibility elements with hints where useful.
- `accessibilityReduceMotion` disables the launch rotation, skeleton pulse and
  thinking indicator.

---

## Security & privacy

- Sessions in the keychain (`kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`).
- Preferences in `UserDefaults` — non-sensitive only.
- OAuth runs in `ASWebAuthenticationSession`; no password is typed in-app.
- `LoopLog` logs categories and error titles, never tokens, amounts or payloads.
- `LoopError` maps transport failures to safe copy — no SQL, stack traces or
  provider detail reaches the UI.
- No contacts, location, camera, photo or notification permission is requested
  by the current feature set.

---

## Concurrency

- Project default isolation is `MainActor`.
- Domain models, formatters, errors and rules are explicitly `nonisolated` and
  `Sendable`.
- Services are `@MainActor` protocols with `async throws` members.
- Parallel loads use `async let` (e.g. `PurchaseDetailView` fans out five
  requests, `LiveProtectionService` fans out five tables).
- Cancellation is respected via `.task` / `.task(id:)`; `LoopError.map` folds
  `CancellationError` into `.cancelled`.
