# Third-Party Dependency Inventory

Updated: 2026-08-25

**TECHNICAL INVENTORY — NOT LEGAL ADVICE.** Direct (first-level) production
dependencies for both apps, from `apps/web/package.json` and
`apps/mobile/pubspec.yaml` as of commit `8e4abcf`. Licenses listed are the
package's well-known, currently-published license as of this writing —
verify against the actual installed version's `LICENSE` file before
relying on this for a legal filing, since a dependency can change license
between versions in principle (none of these are known to have done so).

## Web (`apps/web/package.json`)

| Package | Version constraint | License (as published) | Notes |
| --- | --- | --- | --- |
| `@anthropic-ai/sdk` | `^0.117.1` | MIT | Only invoked server-side; see `docs/ASK_LOOP_PROVIDER_ENABLEMENT.md` |
| `@loop/contracts` | `*` (workspace) | N/A — this repo's own package | — |
| `@supabase/ssr` | `^0.12.4` | MIT | |
| `@supabase/supabase-js` | `^2.112.3` | MIT | |
| `next` | `16.3.1` | MIT | |
| `react` / `react-dom` | `19.2.8` | MIT | |

Dev-only (not shipped to production, listed for completeness):
`@axe-core/playwright`, `@playwright/test`, `@tailwindcss/postcss`,
`eslint`, `eslint-config-next`, `tailwindcss`, `typescript` — all MIT.

## Mobile (`apps/mobile/pubspec.yaml`)

| Package | Version constraint | License (as published) | Notes |
| --- | --- | --- | --- |
| `flutter` (SDK) | — | BSD-3-Clause | Google's Flutter SDK itself |
| `cupertino_icons` | `^1.0.8` | MIT | |
| `flutter_riverpod` | `^3.3.2` | MIT | |
| `go_router` | `^17.5.0` | BSD-3-Clause | Official Flutter team package |
| `supabase_flutter` | `^2.17.2` | MIT | |
| `google_fonts` | `^6.2.1` | Apache-2.0 (package) — bundled font files carry their own individual licenses (mostly OFL/Apache) | Fonts are fetched, not literally embedded in the repo |
| `image_picker` | `^1.1.2` | BSD-3-Clause | Official Flutter team plugin (`flutter/packages`) |
| `shared_preferences` | `^2.3.2` | BSD-3-Clause | Official Flutter team plugin |
| `http` | `^1.2.2` | BSD-3-Clause | Official Dart team package |
| `share_plus` | `^13.3.0` | BSD-3-Clause | `fluttercommunity/plus_plugins` |
| `cross_file` | `^0.3.5+4` | BSD-3-Clause | `flutter/packages` |

## What this inventory does not cover

Transitive dependencies (the full resolved dependency graph, which for a
Next.js + Flutter project runs into the hundreds of packages). Every
direct dependency above is a well-known, actively-maintained package from
either its own vendor (Anthropic, Supabase, Vercel/Next.js, Meta/React) or
an official Google/Flutter/Dart team package (`flutter`, `go_router`,
`image_picker`, `shared_preferences`, `http`, `cross_file`) or a
well-established community org (`fluttercommunity/plus_plugins` for
`share_plus`) — none are obscure or unmaintained. For a complete
transitive-dependency legal audit, run a proper SCA tool
(`npx license-checker` for the web workspace with correct workspace
resolution, `flutter pub deps` plus a Dart license-scanning tool for
mobile) with a maintainer present to review edge cases, rather than
treating this document's summary as exhaustive.

## Flutter's built-in license registry

Flutter automatically aggregates every package's license into an in-app
"Licenses" page via `LicenseRegistry` (surfaced through
`showLicensePage`/`AboutDialog` if the app wires it up, or via the
standard Settings-style licenses screen many Flutter apps include). Verify
whether LOOP's own Help/Settings screen already exposes this — if not,
adding the standard Flutter licenses page is a small, low-risk addition
that satisfies most open-source attribution requirements automatically,
without hand-maintaining a license list.
