-- Security hardening pass (found via Supabase's advisor linter after first
-- deploying the schema to a hosted project):
--
-- 1. `set_updated_at` and `current_profile_id` (20260817000001_helpers.sql)
--    were the only two functions in the schema without an explicit
--    `set search_path`, unlike every function added after them. A mutable
--    search_path on a function lets a caller who can create objects
--    earlier in their session's search_path shadow an unqualified
--    reference inside the function body. Neither function currently makes
--    an unqualified reference that's exploitable in practice, but pinning
--    search_path is a one-line fix and removes the class of bug entirely
--    rather than relying on "it happens to be safe today."
--
-- 2. Every `SECURITY DEFINER` function in the schema (the three
--    auth.users/profiles/businesses provisioning triggers, and the four
--    RLS helper functions: has_account_access, is_active_business_member,
--    is_business_admin, shares_active_business) was flagged as callable by
--    `anon` and `authenticated` via PostgREST RPC. None of the earlier
--    migrations explicitly revoked the default Postgres behavior of
--    granting EXECUTE to PUBLIC on function creation.
--
--    Actual exposure was checked, not assumed:
--    - The three `handle_new_*` functions return `trigger`, a pseudo-type
--      Postgres refuses to execute outside real trigger context
--      ("trigger functions can only be called as triggers") -- calling
--      them via /rest/v1/rpc/handle_new_user always errors, regardless of
--      grants. Revoking PUBLIC execute here is hygiene, not a live-bug fix.
--    - The four boolean RLS helpers all key off `auth.uid()` internally;
--      for `anon` (no session) that's NULL, and every comparison against
--      NULL in their WHERE clauses evaluates false -- an anonymous caller
--      gets `false` for any input, no matter what. Not a data leak, but
--      still tightened to match this schema's own intended access model
--      (authenticated-only) rather than relying on the NULL-uid accident.
--
--    Revoking PUBLIC execute and re-granting only to `authenticated` (the
--    role that actually needs these, since RLS policies call them
--    in-query) matches the explicit revoke-then-narrow-grant pattern this
--    schema already uses for every table-level GRANT.

alter function public.set_updated_at() set search_path = public;
alter function public.current_profile_id() set search_path = public;

revoke execute on function public.handle_new_user() from public;
revoke execute on function public.handle_new_profile() from public;
revoke execute on function public.handle_new_business() from public;
revoke execute on function public.has_account_access(uuid) from public;
revoke execute on function public.is_active_business_member(uuid) from public;
revoke execute on function public.is_business_admin(uuid) from public;
revoke execute on function public.shares_active_business(uuid) from public;

grant execute on function public.has_account_access(uuid) to authenticated;
grant execute on function public.is_active_business_member(uuid) to authenticated;
grant execute on function public.is_business_admin(uuid) to authenticated;
grant execute on function public.shares_active_business(uuid) to authenticated;

-- The three handle_new_* functions are never called directly (trigger-only,
-- and Postgres rejects a direct call regardless of grants), so they get no
-- replacement grant -- the triggers that invoke them run under the
-- function's own SECURITY DEFINER privileges, independent of PUBLIC/
-- authenticated EXECUTE grants.
