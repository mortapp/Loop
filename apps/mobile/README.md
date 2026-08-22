# LOOP Mobile

The Flutter mobile app for **LOOP** — one unified value operating system,
covering the full lifecycle: **EARN -> BUY -> OWN -> RETURN / RESELL ->
EARN AGAIN**.

LOOP is not three separate apps. It's a single shared core (identity,
account context, businesses, contacts, items, documents, actions, events,
money/value primitives, design system) with three strongly-typed domain
extensions on top:

- **MAKE** (QuoteCloser) — leads, opportunities, quotes
- **PROTECT** (ReturnGuard) — purchases, returns, warranties
- **RECOVER** (ResellLens) — valuations, listings, sales

## Tech stack

- Flutter + Dart
- [Riverpod](https://riverpod.dev/) for state management
- [go_router](https://pub.dev/packages/go_router) for routing (a
  `StatefulShellRoute` drives the bottom navigation shell)
- [supabase_flutter](https://pub.dev/packages/supabase_flutter) for auth,
  database, and storage

## Project structure

```
lib/
  core/                 Shared primitives used by every screen/engine
    account/            Account-switcher model (personal vs. business context)
    router/             GoRouter setup + StatefulShellRoute
    supabase/           Supabase client bootstrap + Riverpod providers
    theme/               Design system: colors, typography, spacing
    widgets/             Shared widgets (RootShell nav, PlaceholderScreen)
  features/
    today/               Today tab — unified cross-engine action feed
    money/               Money tab — unified value/ledger view
    sell/                Sell tab — RECOVER-facing surface
    business/            Business tab — account/business switching
    ai/                  AI tab — cross-engine assistant
    make/                MAKE (QuoteCloser) domain extension — placeholder
    protect/             PROTECT (ReturnGuard) domain extension — placeholder
    recover/             RECOVER (ResellLens) domain extension — placeholder
  main.dart              App entrypoint
```

The five bottom-navigation tabs (Today, Money, Sell, Business, AI) are the
shared surfaces every user sees. The `make/`, `protect/`, and `recover/`
folders are where each engine's strongly-typed screens/models/providers
will be built out, layered on top of `core/` rather than as disconnected
apps.

## Running locally

1. Install dependencies:

   ```sh
   flutter pub get
   ```

2. Copy `dart_define.example.json` to `dart_define.json` (gitignored,
   **not** committed anywhere in source) and fill in the real values:

   ```sh
   cp dart_define.example.json dart_define.json
   # edit dart_define.json: SUPABASE_URL, SUPABASE_ANON_KEY
   ```

   Then run (or build) with `--dart-define-from-file`, not
   `--dart-define` typed by hand every time -- this is the one
   documented, hard-to-get-wrong command for every build path:

   ```sh
   flutter run --dart-define-from-file=dart_define.json
   flutter build apk --debug --dart-define-from-file=dart_define.json
   flutter build apk --release --dart-define-from-file=dart_define.json
   ```

   **If you omit `dart_define.json` (or leave a value empty), the app
   deliberately refuses to boot into the real UI** — `main.dart` checks
   `SupabaseConfig.isConfigured` before ever initializing Supabase, and
   shows a plain "LOOP can't start" screen instead. This is intentional
   hardening after a real regression: an earlier build run without
   `--dart-define` used to boot normally and reach Google OAuth against
   an unreachable `placeholder.supabase.co` (see
   docs/KNOWN_ISSUES.md) instead of failing loudly. If you see the
   "can't start" screen, you forgot `--dart-define-from-file`, not a
   sign-in bug.

3. In CI, source `dart_define.json`'s contents from your secret store
   (e.g. write the file from secrets in a step) rather than committing
   it or typing values by hand.

## Verifying changes

```sh
dart format .
flutter analyze
flutter test
```

All three should be clean before landing a change.

## Notes

- No Supabase project credentials exist in this repository. Never
  hardcode a URL or anon key in source — always go through
  `--dart-define-from-file=dart_define.json` (see
  `lib/core/supabase/supabase_config.dart`). A build without it refuses
  to boot into the real UI rather than silently misconfiguring itself.
- The account-switcher model in `lib/core/account/` is currently backed by
  a placeholder provider (a single personal account). It's shaped to match
  the real personal/business membership model so the Supabase-backed
  implementation can slot in later without reworking the Business tab UI.
