-- Preserve the existing membership permissions with one permissive policy per
-- command. The prior FOR ALL admin policy overlapped the self/peer policies,
-- forcing PostgreSQL to evaluate multiple equivalent authorization paths.

drop policy if exists "business_members_manage_owner_admin"
  on public.business_members;
drop policy if exists "business_members_select_peers"
  on public.business_members;
drop policy if exists "business_members_select_self"
  on public.business_members;
drop policy if exists "business_members_delete_self"
  on public.business_members;

create policy "business_members_select_accessible"
  on public.business_members for select
  to authenticated
  using (
    profile_id = (select auth.uid())
    or public.is_active_business_member(business_id)
  );

create policy "business_members_insert_owner_admin"
  on public.business_members for insert
  to authenticated
  with check (public.is_business_admin(business_id));

create policy "business_members_update_owner_admin"
  on public.business_members for update
  to authenticated
  using (public.is_business_admin(business_id))
  with check (public.is_business_admin(business_id));

create policy "business_members_delete_self_owner_admin"
  on public.business_members for delete
  to authenticated
  using (
    profile_id = (select auth.uid())
    or public.is_business_admin(business_id)
  );
