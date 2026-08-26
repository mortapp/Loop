# SECURITY DEFINER Function Inventory

Updated: 2026-08-25

Every `SECURITY DEFINER` function in the schema, found by grepping
`supabase/migrations/*.sql` for `security definer`. All 13 set an explicit
`search_path` (either `public` or `''`), closing the classic
search-path-shadowing attack (a caller creating an object earlier in their
session's search path to hijack an unqualified reference) — see
`20260821235226_harden_function_search_path_and_grants.sql` for the general
fix and rationale.

Only 7 are reachable by an authenticated client via
`/rest/v1/rpc/<name>` (flagged by the Supabase security advisor as
`authenticated_security_definer_function_executable`, `WARN`/informational,
not a defect by itself — the advisor flags every SECURITY DEFINER function
callable by a signed-in user so a human reviews each one). The other 6 are
trigger functions with no PostgREST grant, invoked only by Postgres itself
on insert/update.

## Callable via RPC (authenticated role)

| Function | Purpose | search_path | Account/auth binding | Risk if bypassed | Evidence |
| --- | --- | --- | --- | --- | --- |
| `has_account_access(target_account_id uuid)` | Core RLS predicate — the single gate nearly every table's policy calls | `public` | Checks `auth.uid()` against `business_members`/account ownership | Would be a total tenant-isolation bypass | 209-case DB suite; used in every RLS policy |
| `is_active_business_member(target_business_id uuid)` | RLS helper for business-scoped tables | `public` | `auth.uid()`-bound | Cross-business data leak | DB suite `005_business_members_rls.sql` |
| `is_business_admin(target_business_id uuid)` | RLS helper gating admin-only writes (e.g. role changes) | `public` | `auth.uid()`-bound | Privilege escalation within a business | DB suite `005_business_members_rls.sql`, `007_account_graph_integrity.sql` |
| `shares_active_business(target_profile_id uuid)` | RLS helper for profile-to-profile visibility within a shared business | `public` | `auth.uid()`-bound | Cross-account profile leak | DB suite `005_business_members_rls.sql` |
| `is_username_available(candidate text)` | Onboarding username-availability check | `public` (set twice — inline and via explicit `alter function`) | No account context needed; read-only existence check | Username enumeration only (already public-facing UX) | DB suite `006_usernames.sql` |
| `create_quote_with_line_items(...)` | The **only** path that can create a quote + its line items | `public` (upgraded to SECURITY DEFINER in `20260824010900` specifically so direct `insert`/`update`/`delete` on `quotes`/`quote_line_items` could be revoked from `authenticated`) | Validates `p_account_id` against `auth.uid()`, validates every line item, computes totals server-side | A caller-controlled account/total | DB suite `002_quote_rpc.sql`, `013_quote_write_authority.sql` |
| `set_quote_status_with_money_event(p_quote_id uuid, p_status quote_status)` | The only path that can transition quote status; atomically writes exactly one Money event when transitioning to `accepted` | `''` (fully qualified references only) | Validates the quote's account against `auth.uid()`, enforces forward-only status transitions | Duplicate Money events or unauthorized quote acceptance | DB suite `014_quote_acceptance_money.sql`; physically re-verified this session (`docs/LOOP_FINAL_STATE.md`) |

## Trigger-only (not directly callable by any client)

| Function | Purpose | search_path |
| --- | --- | --- |
| `handle_new_user()` | Bootstraps a profile/account row when a new `auth.users` row is inserted | `public` |
| `handle_new_profile()` | Post-profile-insert bookkeeping | `public` |
| `handle_new_business()` | Bootstraps `business_members` ownership row when a business is created | `public` |
| `enforce_same_account_reference()` | Account-graph integrity trigger — rejects a row whose foreign keys span two different accounts | `''` |
| `enforce_profile_account_reference()` | Account-graph integrity trigger for profile-linked rows | `''` |
| `sync_profile_email_from_auth()` | Keeps `profiles.email` in sync with `auth.users.email` | `''` |

None of these are granted `EXECUTE` to `authenticated`/`anon` directly and
none are exposed through PostgREST — they only run as Postgres trigger
bodies, so there is no client-reachable call path into them. Their behavior
is covered by `007_account_graph_integrity.sql` and the identity/business
tests.

## What was verified, not assumed

- Grepped every `security definer` occurrence in `supabase/migrations/*.sql`
  and cross-referenced against the current hosted advisor output
  (`get_advisors(type: security)` on `zqalnvfwxmfrnyjcuehq`) — the 7-function
  list matches exactly, no new SECURITY DEFINER function has been added
  since the advisor was last reviewed.
- Confirmed every function has a `search_path` set (no function relies on
  the caller's mutable search path).
- No function accepts a caller-controlled `role`, bypasses `auth.uid()`
  binding, or lets a client set an arbitrary `account_id`/`user_id` that
  isn't independently validated against the authenticated session.

## Not changed tonight

None of these functions were modified — they are already hardened and
covered by the 209-case pgTAP suite. No refactor was performed; a working,
tested security boundary was left alone per this session's conservative
runtime-change policy.
