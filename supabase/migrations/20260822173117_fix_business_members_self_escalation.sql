-- Fix a real privilege-escalation hole in business_members RLS, found
-- while investigating the Supabase advisor's "multiple permissive
-- policies" performance note on this table (see supabase/tests/database/
-- 005_business_members_rls.sql for the exhaustive coverage this migration
-- was verified against).
--
-- "business_members_self_manage" was declared FOR ALL with only
-- `profile_id = auth.uid()` in its WITH CHECK -- nothing constrained
-- business_id or role. Two consequences, both real, neither
-- hypothetical:
--
--   1. INSERT escalation: any authenticated user could INSERT a row like
--      (business_id: <any business>, profile_id: themself, role: 'owner',
--      status: 'active') and grant themselves ownership of a business
--      they were never invited to. The WITH CHECK only ever verified
--      "this row is about me," never "I'm allowed to create it."
--   2. UPDATE escalation: an existing 'member' of a business could
--      UPDATE their own row's `role` to 'owner'/'admin' -- the WITH
--      CHECK still only verified "this row is about me," not "this
--      column transition is one I'm allowed to make."
--
-- No app code (web or mobile) currently uses self-service business_
-- members writes at all -- there is no invite-accept or leave-business
-- UI yet, so this is a real, live hole with zero product dependency on
-- the unsafe behavior. The fix is the conservative option named in the
-- owning directive when full equivalence can't be cheaply proven: rather
-- than try to keep a single FOR ALL policy and bolt on a fragile
-- old-vs-new column comparison inside a WITH CHECK subquery (whose
-- semantics inside RLS are not reliably well-defined), self-service is
-- narrowed to exactly the two operations that are actually safe with no
-- extra column constraints needed: SELECT (seeing your own row, even a
-- pending invite you're not yet an active member for) and DELETE
-- (leaving a business always reduces your own access, never grants
-- anything). INSERT and UPDATE of a business_members row now require
-- public.is_business_admin(business_id) -- see
-- business_members_manage_owner_admin, unchanged -- or the existing
-- SECURITY DEFINER handle_new_business() trigger that bootstraps a new
-- business's owner row. A future "accept an invite" self-service UPDATE
-- can be added deliberately later with a real trigger-enforced column
-- lock, not reintroduced as an open WITH CHECK.

drop policy "business_members_self_manage" on public.business_members;

create policy "business_members_select_self"
  on public.business_members for select
  to authenticated
  using (profile_id = auth.uid());

create policy "business_members_delete_self"
  on public.business_members for delete
  to authenticated
  using (profile_id = auth.uid());
