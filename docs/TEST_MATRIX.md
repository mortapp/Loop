# LOOP Test Matrix

| Area | Test | Expected | Result | Evidence |
|---|---|---|---|---|
| Foundation | Initial verification | Repository structure exists | Pass | Repo inspected 2026-08-17 |
| Supabase local stack | `supabase start` / `db reset` applies all migrations 0001-0007 cleanly | No SQL errors | Pass | Local run 2026-08-17, all containers healthy |
| Identity | Sign up user → profile auto-created | 1 profile row matching auth.users id | Pass | REST smoke test 2026-08-17 |
| Identity | Sign up user → personal account auto-created | 1 `accounts` row, `type=personal`, `owner_profile_id` = user | Pass | REST smoke test 2026-08-17 |
| Identity | User creates a business (with `Prefer: return=representation`) | 201, business row returned, no RLS error | Pass (after fix — see docs/KNOWN_ISSUES.md) | REST smoke test 2026-08-17 |
| Identity | Business creation auto-provisions owner membership + business account | `business_members` has 1 `owner`/`active` row; `accounts` gains a `type=business` row | Pass | REST smoke test 2026-08-17 |
| RLS isolation | User B reads `items` while only User A has rows | Empty array, not an error | Pass | REST smoke test 2026-08-17 |
| RLS isolation | User B reads User A's `profiles` row by id (no shared business) | Empty array | Pass | REST smoke test 2026-08-17 |
| RLS isolation | User B reads User A's `businesses` (not a member) | Empty array | Pass | REST smoke test 2026-08-17 |
| Grants | Authenticated user inserts into `items`, `businesses`, `money_events` | Succeeds (previously `42501` before explicit GRANTs were added) | Pass (after fix — see docs/KNOWN_ISSUES.md) | REST smoke test 2026-08-17 |
| Ledger semantics | Insert into `money_events` | Succeeds, row returned | Pass | REST smoke test 2026-08-17 |

Method: local Supabase stack (`supabase/config.toml`, ports 55321-55329)
driven via raw `curl` against `/auth/v1` and `/rest/v1` with two
throwaway signed-up users, cross-checked with direct `psql` queries where
REST responses alone couldn't distinguish the root cause. No automated
test suite exists yet — see docs/KNOWN_ISSUES.md and docs/ROADMAP.md for
that gap.
