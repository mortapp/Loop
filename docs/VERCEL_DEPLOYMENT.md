# LOOP Web — Vercel Deployment

Deployment readiness notes for `apps/web` (the Next.js/TypeScript web
client for LOOP's MAKE/PROTECT/RECOVER engines). This document covers
what is configured, what Vercel needs to be told, and what remains a
human decision.

## Architecture

LOOP is an npm-workspaces monorepo:

```
Loop/                        <- workspace root (package-lock.json lives here)
  package.json                package.json declares "workspaces": ["apps/web", "packages/*"]
  apps/
    web/                     <- this app (Next.js App Router, TypeScript, Tailwind)
    mobile/                  <- Flutter, not part of the npm workspace, irrelevant to this doc
  packages/
    contracts/               <- @loop/contracts: shared zod schemas/types, mirrors supabase/migrations
    shared-config/           <- shared eslint/tsconfig/prettier bases
    domain-docs/
  supabase/                  <- local Postgres/Auth/Storage stack (Docker), not deployed to Vercel
```

`apps/web` depends on the workspace package `@loop/contracts` (see its
`package.json`: `"@loop/contracts": "*"`). That dependency only resolves
correctly if `npm install`/`npm ci` runs from the **monorepo root**, not
from inside `apps/web` — see "Root Directory" below.

Only `apps/web` is deployed to Vercel. `apps/mobile` (Flutter) and
`supabase/` (local Docker stack) are unrelated to this deployment.

## GitHub Repository

`https://github.com/mortapp/Loop.git` (not yet pushed as of this
writing — see docs/AUTONOMOUS_BUILD_STATUS.md). Vercel's GitHub
integration will be pointed at this repo, not a fork or mirror.

## Root Directory

Set the Vercel Project's **Root Directory** to:

```
apps/web
```

### Why this works with npm workspaces (no `vercel.json` needed)

Vercel documents that when it detects a monorepo — a root-level
lockfile (`package-lock.json` here) plus a `workspaces` field in the
root `package.json` — it automatically runs the install step from the
**monorepo root**, not from the configured Root Directory, so that
workspace-linked dependencies like `@loop/contracts` resolve correctly.
The build step then runs scoped to the Root Directory (`apps/web`) as
normal. This is standard behavior for npm/yarn/pnpm workspace monorepos
and does not require a custom `installCommand` or `buildCommand`.

Verified locally: `npm ci` (or `npm install`) from the repo root
followed by `npm run build --workspace apps/web` succeeds and resolves
`@loop/contracts` via a workspace symlink at
`node_modules/@loop/contracts -> packages/contracts`. This mirrors what
Vercel will do.

**One setting to confirm by hand in the Vercel dashboard** (Project
Settings → General): "Include files outside the Root Directory in the
Build Step" should be **enabled**. Vercel enables this automatically
when it detects a monorepo at project creation, but it's worth
confirming — without it, the workspace packages under `packages/*`
would not be visible during install.

We deliberately did **not** add `apps/web/vercel.json` — Vercel's
monorepo auto-detection covers this case, and a hand-written
`installCommand`/`buildCommand` override would be one more thing to
keep in sync with root `package.json` for no benefit. Revisit only if
Vercel's build logs show `@loop/contracts` failing to resolve.

## Framework

Next.js (App Router), auto-detected by Vercel via `apps/web/package.json`
(`"next": "16.3.1"`). No framework preset override needed.

- Package manager: npm (root `package-lock.json` is the lockfile Vercel
  will detect).
- Node: repo root `package.json` declares `"engines": { "node": ">=20" }`.

## Environment Variables

Names only — see root `.env.example` for the canonical list. Never put
real values in any committed file.

| Variable | Client-safe? | Purpose |
|---|---|---|
| `NEXT_PUBLIC_SUPABASE_URL` | Yes (`NEXT_PUBLIC_*`) | Supabase project URL, used by the browser client. |
| `NEXT_PUBLIC_SUPABASE_ANON_KEY` | Yes (`NEXT_PUBLIC_*`) | Supabase anon/publishable key. Safe to ship to the browser by design — see "Supabase" below. |
| `NEXT_PUBLIC_SITE_URL` | Yes (`NEXT_PUBLIC_*`) | Base URL used to build absolute links (e.g. Supabase Auth redirect/callback URLs). Must be set per-environment — see "Preview Deployments" below. |

No server-only secret is required yet. If a future feature needs the
Supabase `service_role` key (privileged, bypasses RLS) or another
server-only credential, it must be added **without** the `NEXT_PUBLIC_`
prefix (so Next.js never inlines it into the client bundle) and marked
sensitive/encrypted in Vercel's env var UI. Nothing in `apps/web`
currently needs this.

Set in Vercel (Production and Preview scopes; Development scope only
matters for `vercel dev`, which this project's local flow doesn't use)
— done 2026-08-21, pointing at the hosted Supabase project
(`zqalnvfwxmfrnyjcuehq`). Local `apps/web/.env.local` uses the same
hosted values now too, since Docker isn't running in this environment
— see docs/KNOWN_ISSUES.md.

## Supabase

`apps/web`'s dependencies (`@supabase/supabase-js`, `@supabase/ssr`)
connect using `NEXT_PUBLIC_SUPABASE_URL` and
`NEXT_PUBLIC_SUPABASE_ANON_KEY`. These are intentionally public:

- The `anon` key identifies the Supabase project's public API endpoint;
  it does not itself grant access to data.
- **Row Level Security (RLS)** on every table (see
  `supabase/migrations/`, and `docs/DECISIONS.md` /
  `docs/KNOWN_ISSUES.md` for the account-scoping model) is the actual
  security boundary. A request authenticates as a specific user (via
  Supabase Auth) and RLS policies scope every row to that user's
  account access — the anon key alone cannot read or write data outside
  RLS-permitted rows.
- This is Supabase's documented model: the anon key is safe to embed in
  client-side code as long as RLS is enabled and correct on every
  table. LOOP's migrations already do this (verified end-to-end per
  `docs/TEST_MATRIX.md`).

Do not mark `NEXT_PUBLIC_SUPABASE_ANON_KEY` as a Vercel "sensitive"
env var purely out of caution — it doesn't need encryption-at-rest
protection beyond what any other client-visible config gets, since it's
shipped to every browser anyway. (Marking it sensitive is harmless if
preferred, just not required.)

## Authentication

As of this writing, the parallel workstream building `apps/web/src` has
already landed the Supabase Auth wiring this doc originally anticipated
as forward-looking. What exists today:

- Browser client: `apps/web/src/lib/supabase/client.ts`
  (`createBrowserClient` from `@supabase/ssr`, using
  `NEXT_PUBLIC_SUPABASE_URL` / `NEXT_PUBLIC_SUPABASE_ANON_KEY`).
- Server client: `apps/web/src/lib/supabase/server.ts`
  (`createServerClient`, cookie-based, for Server Components/Actions/
  Route Handlers).
- PKCE callback route: `apps/web/src/app/auth/callback/route.ts` —
  exchanges the `code` query param for a session and redirects using
  the **incoming request's own origin** (`new URL(request.url).origin`),
  not a hardcoded or env-baked URL. This is exactly right for Vercel:
  it means the same code works unmodified on localhost, every preview
  deployment, and production without needing `NEXT_PUBLIC_SITE_URL` at
  redirect-resolution time.
- Session refresh + route gating: `apps/web/src/proxy.ts` — Next.js 16
  renamed the `middleware.ts` convention to `proxy.ts` (same runtime
  behavior; see the in-file comment and
  `node_modules/next/dist/docs/.../file-conventions/proxy.md`). Runs on
  every request to keep the Supabase session cookie fresh and redirect
  unauthenticated users away from the app shell.
- Sign-up's `emailRedirectTo` (`apps/web/src/app/(auth)/actions.ts`) is
  the one place that does read `NEXT_PUBLIC_SITE_URL` directly (an
  email confirmation link is generated server-side ahead of any
  request context, so it can't derive an origin from an incoming
  request the way the callback route does) — confirming
  `NEXT_PUBLIC_SITE_URL` must be set correctly per Vercel environment
  (see "Environment Variables" and "Preview Deployments").

Still to come (not blocking initial deployment): OAuth providers
(Google — see below) are not wired up yet, only email/password.

Supabase Auth's redirect allow-list must include each environment's
URL(s) — see "Preview Deployments" and "Human Action Required" below.

## Local Development

From the repo root (this is an npm workspaces monorepo — install and
most scripts run from root, not from inside `apps/web`):

```bash
npm ci
npm run dev --workspace apps/web       # http://localhost:3000
npm run lint --workspace apps/web
npm run typecheck --workspace apps/web
npm run build --workspace apps/web
```

Root-level convenience scripts (`package.json`) also exist:
`npm run dev` / `npm run build` (both already scoped to
`apps/web`), and `npm run lint` / `npm run typecheck` (run across all
workspaces that define the script — currently `apps/web` and
`packages/contracts`).

Local development also needs a running Supabase stack
(`supabase start`, see `supabase/config.toml` — ports 55321-55329,
isolated from any other local Supabase project on this machine) and a
populated `apps/web/.env.local` (Next.js only reads `.env.local` from
the app directory itself, not the repo root — copy
`apps/web/.env.local.example`, which points back at root
`.env.example` as the canonical variable list, and fill in values from
`supabase status -o env`).

**Windows/OneDrive note:** if this repo lives inside a OneDrive-synced
folder (as it does in this environment), `npm install`/`npm ci` can
intermittently drop files during tarball extraction (`npm warn tar
TAR_ENTRY_ERROR ENOENT`), most often observed on `@supabase/ssr`,
silently producing a package missing its `.d.ts` files and causing
spurious `tsc` errors ("Could not find a declaration file for module
'@supabase/ssr'") that look like real type errors but aren't. If
`typecheck` fails with that specific error, delete
`node_modules/@supabase/ssr` and reinstall
(`npm install @supabase/ssr@<version> -w apps/web`) rather than
debugging application code. This is a local Windows/OneDrive
filesystem quirk, not something that affects Vercel's (Linux) build
environment.

## Vercel Setup (human steps)

1. Go to https://vercel.com and sign in (or create an account/team for
   LOOP).
2. "Add New… → Project" → import `mortapp/Loop` from GitHub (requires
   the GitHub App/OAuth connection to be authorized for that repo/org
   first).
3. When prompted for the project root, set **Root Directory** to
   `apps/web`. Vercel should auto-detect Next.js and npm workspaces at
   this point; confirm "Include files outside the Root Directory in the
   Build Step" is enabled (see "Root Directory" above).
4. Leave Build/Install/Output commands on their auto-detected defaults
   unless a future issue proves otherwise (see justification above).
5. Add the environment variables listed above (Production, Preview, and
   Development scopes) with real values from wherever the hosted
   Supabase project ends up living.
6. Deploy.

## Preview Deployments

Every pull request / non-production branch push gets its own preview
deployment at a dynamic `https://<project>-<hash>-<team>.vercel.app`
URL. Vercel auto-injects `VERCEL_URL` (the deployment's own hostname,
no protocol) and `VERCEL_ENV` (`production` / `preview` / `development`)
into the build and runtime environment — these can be used to derive
`NEXT_PUBLIC_SITE_URL` per-deployment if a static env var isn't set, or
to override it. Whichever approach the auth implementation takes, the
resulting URL for each preview must be added to Supabase Auth's redirect
allow-list (see "Human Action Required") or PKCE callback exchanges will
fail with a redirect-not-allowed error on every preview.

## Production Deployment — LIVE since 2026-08-21

**https://loop-teal-rho.vercel.app** — real production deployment,
verified live (fetched directly: renders the actual sign-in UI, correct
tagline, zero runtime errors). This section originally described a
not-yet-real production state; that was stale. What actually happened:

A Vercel project (`loop`, team `mortapphelp-7067s-projects`) and a
hosted Supabase project (`zqalnvfwxmfrnyjcuehq`) had both already been
created (2026-08-17) but neither had been finished — the Vercel
project's Root Directory was never set to `apps/web` and its Framework
Preset was stuck on "Other", so all 13 prior deployment attempts had
built successfully and then failed at the very last step looking for a
static `public/` directory that a Next.js app doesn't have. Root cause
found from the actual build log (`get_deployment_build_logs`), not
guessed. Fixed both settings via the dashboard, added the three
`NEXT_PUBLIC_*` env vars (previously unset) to Production and Preview
scopes, redeployed — first `READY` production build in the project's
history.

Remaining, still genuinely open:
- No custom production domain chosen yet — serving from the generated
  `loop-teal-rho.vercel.app` (do not hardcode this or any domain
  anywhere in code).
- Google OAuth is not configured (see below); email/password auth is
  implemented and functional (see "Authentication").
- `ANTHROPIC_API_KEY` still unset — AI chat shows its "not configured"
  state in production, honestly, rather than a broken chat UI.

## Build Verification

Run from the repo root against the current tree (2026-08-17):

| Command | Result |
|---|---|
| `npm ci` (root) | Pass — resolves `@loop/contracts` and all `@supabase/*` packages via workspace linking. |
| `npm run lint --workspace apps/web` | Pass, no errors/warnings. |
| `npm run typecheck --workspace apps/web` | Pass (script added — `create-next-app` doesn't ship one by default; `apps/web/package.json` now has `"typecheck": "tsc --noEmit"`, matching what `.github/workflows/web-ci.yml` already expects). |
| `npm run build --workspace apps/web` | Pass — `next build` (Turbopack) compiles, typechecks, and prerenders all 10 routes; proxy/middleware picked up correctly. |

These are the same four commands `.github/workflows/web-ci.yml` runs in
CI, so a clean local run here is a strong signal CI will also pass.

## Google OAuth

Not yet configured anywhere. Once Supabase Auth's Google provider is
set up (hosted project, human step), the Google Cloud OAuth client's
"Authorized redirect URIs" will need the Supabase project's callback
URL, and — once a Vercel production/preview URL or custom domain
exists — that URL's equivalent Supabase redirect entry. This is pure
external configuration (Google Cloud Console + Supabase Auth settings),
nothing in `apps/web` code needs to change to support it beyond the
generic env-var-driven redirect handling described above.

## Human Action Required

Done, struck through; still genuinely open below:

- ~~Create/own the Vercel account or team LOOP deploys under.~~
- ~~Authorize Vercel's GitHub App for `mortapp/Loop` and import the
  project.~~
- ~~Set real environment variable values in Vercel (Supabase URL/anon
  key, site URL).~~ Done for Production/Preview; Development scope
  (only relevant to `vercel dev`, which this project's local flow
  doesn't use) was left unset.
- ~~Create a hosted Supabase project.~~ Done, migrated, and hardened
  2026-08-21 — see docs/KNOWN_ISSUES.md and "Deployed" in
  docs/AUTONOMOUS_BUILD_STATUS.md.

Still open:
- Choose and configure a custom production domain (none chosen yet —
  currently serving from the generated `loop-teal-rho.vercel.app`).
- Populate the hosted Supabase project's Auth redirect allow-list
  (`additional_redirect_urls`) with `localhost`, every Preview
  deployment's pattern, and the eventual production domain — needed
  before Google OAuth or email-confirmation redirects will work
  end-to-end on the hosted project.
- Create Google OAuth credentials (Google Cloud Console) and wire them
  into Supabase Auth's Google provider.
- Set `ANTHROPIC_API_KEY` (and optionally `ANTHROPIC_MODEL`) for AI
  chat to make real model calls.
