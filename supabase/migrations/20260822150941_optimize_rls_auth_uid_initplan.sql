-- Performance advisor: these 5 policies re-evaluate auth.uid() once per
-- row instead of once per query. Wrapping in (select auth.uid()) lets
-- Postgres's query planner cache it as an InitPlan. Semantics unchanged --
-- verified against pg_policies before writing this, each qual/with_check
-- reproduced exactly, only auth.uid() -> (select auth.uid()).

drop policy "business_members_self_manage" on public.business_members;
create policy "business_members_self_manage"
  on public.business_members for all
  to authenticated
  using (profile_id = (select auth.uid()))
  with check (profile_id = (select auth.uid()));

drop policy "businesses_insert_authenticated" on public.businesses;
create policy "businesses_insert_authenticated"
  on public.businesses for insert
  to authenticated
  with check (created_by = (select auth.uid()));

drop policy "businesses_select_members" on public.businesses;
create policy "businesses_select_members"
  on public.businesses for select
  to authenticated
  using (created_by = (select auth.uid()) or is_active_business_member(id));

drop policy "profiles_select_self_or_business_peers" on public.profiles;
create policy "profiles_select_self_or_business_peers"
  on public.profiles for select
  to authenticated
  using (id = (select auth.uid()) or shares_active_business(id));

drop policy "profiles_update_self" on public.profiles;
create policy "profiles_update_self"
  on public.profiles for update
  to authenticated
  using (id = (select auth.uid()))
  with check (id = (select auth.uid()));
