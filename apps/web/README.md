# LOOP web (apps/web)

Next.js 16 (App Router, TypeScript, Tailwind v4), the web client for LOOP.
Shares its data model with `apps/mobile` via `supabase/migrations` and
`@loop/contracts` — see `packages/domain-docs/README.md` for the full
picture.

## Local development

1. From the repo root, start the local Supabase stack (once — see
   `supabase/config.toml`; ports 55321-55329, isolated from any other
   local Supabase project on this machine):

   ```bash
   npx supabase start
   npx supabase status -o env   # prints API_URL / ANON_KEY
   ```

2. Copy `.env.local.example` to `.env.local` in this directory and fill
   in `NEXT_PUBLIC_SUPABASE_URL` / `NEXT_PUBLIC_SUPABASE_ANON_KEY` from
   the output above.

3. From the repo root (this is an npm workspace):

   ```bash
   npm install
   npm run dev --workspace apps/web
   ```

## Scripts

Run from the repo root as `npm run <script> --workspace apps/web`, or
from this directory directly:

- `dev` — start the dev server
- `build` — production build
- `lint` — ESLint
- `typecheck` — `tsc --noEmit`

## Structure

- `src/proxy.ts` — Next.js 16's renamed `middleware.ts`. Refreshes the
  Supabase session cookie on every request and gates `(app)/**` behind
  auth.
- `src/lib/supabase/{client,server}.ts` — browser and server Supabase
  clients (`@supabase/ssr`).
- `src/app/(auth)/` — sign-in / sign-up, server actions in `actions.ts`.
- `src/app/auth/callback/route.ts` — PKCE callback (email confirmation,
  future OAuth).
- `src/app/(app)/` — the authenticated shell and the five primary
  product areas (`src/lib/nav.ts`): Today, Money, Sell, Business, AI.
  Today/Money/Sell/AI are placeholders pending their domain UIs;
  Business is wired up for real (lists your accounts, lets you create a
  business).

## Deployment

See `docs/VERCEL_DEPLOYMENT.md` at the repo root.
