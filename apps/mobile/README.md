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

2. Run the app. Supabase credentials are supplied via `--dart-define` and
   are **not** committed anywhere in source:

   ```sh
   flutter run \
     --dart-define=SUPABASE_URL=https://your-project.supabase.co \
     --dart-define=SUPABASE_ANON_KEY=your-anon-key
   ```

   If you omit these, the app still boots — `SUPABASE_URL` /
   `SUPABASE_ANON_KEY` default to empty strings and Supabase is
   initialized with placeholder values, so any auth/data call will fail
   until real credentials are provided. This is expected for local UI
   work before a live Supabase project is wired up.

3. To build a release artifact, pass the same `--dart-define` flags to
   `flutter build apk` / `flutter build ios`, ideally sourced from your
   CI secret store rather than typed by hand.

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
  `--dart-define` (see `lib/core/supabase/supabase_config.dart`).
- The account-switcher model in `lib/core/account/` is currently backed by
  a placeholder provider (a single personal account). It's shaped to match
  the real personal/business membership model so the Supabase-backed
  implementation can slot in later without reworking the Business tab UI.
