# LOOP iOS — handoff

Everything in this document is work that **cannot** be completed inside the build
environment because it needs an account, a credential, a deployment or a legal
decision. Everything else is already implemented.

---

## 1. What you receive

- A complete Xcode project (`LOOP.xcodeproj`) with no third-party dependencies.
- 5 primary tabs, 40+ screens, a full design system, a typed navigation layer and
  a deep-link router.
- A complete domain model with the Today rule engine.
- Two full service environments behind one set of protocols: live Supabase and a
  quarantined sample environment.
- A Swift Testing suite over money maths, quote/sale calculations, deadlines,
  deep links, Today rules, cross-feature flows and error mapping.
- Documentation: `README.md`, `IOS_ARCHITECTURE.md`, `BACKEND_INTEGRATION.md`,
  `FEATURE_MATRIX.md`, this file.

Run it now: open the project, build the `LOOP` scheme, press Run. The app boots
into a labelled sample account with coherent, connected records.

---

## 2. External blockers

### 2.1 Supabase project — **required**

1. Create the project.
2. Create the tables listed in `BACKEND_INTEGRATION.md §3`.
3. Enable RLS on every table with a policy limiting rows to the caller's accounts.
4. Create the RPCs listed in `§4`. Port `Domain/Today/ActionRules.swift` into
   `generate_today_actions` + `actions` so app and server agree.
5. Supply `SUPABASE_URL` and `SUPABASE_ANON_KEY` as build configuration.

Until this exists the app runs in sample mode and every live service throws
`LoopError.serviceUnavailable` — by design, never a silent fixture fallback.

### 2.2 Google OAuth client — **required for sign-in**

- Create the OAuth client, add it as a Supabase Auth provider.
- Allow the redirect `com.loop.app.loop_mobile://login-callback`.
- Confirm the `loop` URL scheme in the target's Info settings when you take over
  signing.

### 2.3 Ask LOOP server — **required for live intelligence**

Deploy `POST {LOOP_API_BASE_URL}/ask-loop` (contract in
`BACKEND_INTEGRATION.md §5`). The model credential lives there and nowhere else.
Until it exists, Ask LOOP clearly states its answers are generated on-device from
sample records.

### 2.4 Document storage — **required to open files**

Create the private Storage bucket and private Supabase Storage signed URLs. Document
*metadata* already works end-to-end; only the file payload is missing, and the
UI says so instead of pretending.

### 2.5 Apple Developer signing — **required to ship**

Team ID, bundle identifier, provisioning. Nothing in the code blocks this.

### 2.6 Push notifications — **required for reminders**

APNs key + a scheduled server job driven by `generate_today_actions` + `actions`. The action
catalogue and the contextual permission moment are already designed; no
permission is requested at launch.

### 2.7 Legal copy — **required for App Store**

The About screen routes to privacy and terms but deliberately contains no
fabricated policy text. Supply the published copy or the URLs.

---

## 3. First tasks after connecting the backend

1. Set the three configuration keys → the sample banner disappears automatically.
2. Verify sign-in end-to-end, including the callback into `AppState`.
3. Seed one real account and walk the three cross-feature flows:
   - purchase → return → refund → Money
   - lead → opportunity → quote → won → income → Money
   - owned item → sale → net proceeds → Money
4. Compare server-generated Today actions against the local rule engine output.
5. Turn on notifications once the scheduled job is live.

---

## 4. Conventions to keep

- **Money is `Decimal`.** Never introduce `Double` into an amount.
- **Views depend on protocols.** If a view imports a service implementation,
  that's a regression.
- **No fixture fallback in production services.** Show the error state.
- **No secrets in the client.** Publishable values only.
- **Status is never colour-only.** Every badge keeps its glyph and label.
- **Don't claim automation LOOP doesn't perform.** The copy in Returns, Sell and
  Quotes is deliberate.

---

## 5. Known limitations

- Live services are implemented but unexercised until a backend exists.
- Document upload records metadata only.
- Resale estimates are user-entered; no market data provider is integrated.
- Multi-account exists in the model and UI; server-side multi-account policies
  still need writing.
- No offline write queue — LOOP reads and mutates online, and reports failures
  honestly rather than queueing silently.
