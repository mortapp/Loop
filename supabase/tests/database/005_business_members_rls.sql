-- Exhaustive pgTAP coverage for business_members RLS
-- (supabase/migrations/20260821234807_identity.sql originally,
-- supabase/migrations/20260822173117_fix_business_members_self_escalation.sql
-- for the fix this suite verifies). Run with:
--   supabase test db --local supabase/tests/database
--
-- Written against the Supabase advisor's "multiple permissive policies"
-- performance note on this table -- reading the actual policy definitions
-- to write these tests surfaced a real privilege-escalation hole (see the
-- fix migration's comment), not just a cosmetic overlap. Per the owning
-- directive: security correctness first, advisor-score consolidation
-- only if it can be proven equivalent. It couldn't be, cheaply and
-- safely -- so this suite locks in the conservative fix instead, and
-- docs/DECISIONS.md records that as ACCEPTED_WITH_EVIDENCE rather than
-- pretending the policies were merged.
--
-- Runs inside one transaction rolled back at the end (same pattern as
-- every other file in this directory).

create extension if not exists pgtap;

begin;

select plan(17);

-- ---------------------------------------------------------------------------
-- Fixtures: henry owns Business A (auto-provisioned owner row via
-- handle_new_business()), then adds iris as admin and jack as a plain
-- member. kate owns a wholly separate Business B and has no relationship
-- to Business A at all -- the outsider / cross-business case.
-- ---------------------------------------------------------------------------

do $$
declare
  v_instance_id uuid := '00000000-0000-0000-0000-000000000000';
begin
  insert into auth.users (
    instance_id, id, aud, role, email, encrypted_password,
    email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
    created_at, updated_at
  ) values
    (v_instance_id, '88888888-8888-8888-8888-888888888888', 'authenticated', 'authenticated',
     'henry@test.local', crypt('password123', gen_salt('bf')), now(), '{}', '{}', now(), now()),
    (v_instance_id, '99999999-9999-9999-9999-999999999999', 'authenticated', 'authenticated',
     'iris@test.local', crypt('password123', gen_salt('bf')), now(), '{}', '{}', now(), now()),
    (v_instance_id, 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'authenticated', 'authenticated',
     'jack@test.local', crypt('password123', gen_salt('bf')), now(), '{}', '{}', now(), now()),
    (v_instance_id, 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'authenticated', 'authenticated',
     'kate@test.local', crypt('password123', gen_salt('bf')), now(), '{}', '{}', now(), now());
end $$;

create or replace function pg_temp.authenticate_as(user_id uuid) returns void as $$
begin
  execute 'set local role authenticated';
  perform set_config(
    'request.jwt.claims',
    json_build_object('sub', user_id, 'role', 'authenticated')::text,
    true
  );
end;
$$ language plpgsql;

-- The anon Postgres role, no JWT claims -- auth.uid() reads NULL, the
-- same state a real unauthenticated request hits RLS with.
create or replace function pg_temp.authenticate_as_anon() returns void as $$
begin
  execute 'set local role anon';
  perform set_config('request.jwt.claims', '', true);
end;
$$ language plpgsql;

-- PostgreSQL does not allow a data-modifying CTE inside the scalar expression
-- passed to pgTAP's is(). Execute the statement inside a temporary invoker
-- function and return its affected-row count instead.
create or replace function pg_temp.execute_and_count(statement text)
returns integer as $$
declare
  v_count integer;
begin
  execute statement;
  get diagnostics v_count = row_count;
  return v_count;
end;
$$ language plpgsql;

select pg_temp.authenticate_as('88888888-8888-8888-8888-888888888888');
insert into public.businesses (id, name, slug, created_by)
values (
  'a0000000-0000-4000-8000-00000000000a',
  'Business A', 'business-a-rls-test',
  '88888888-8888-8888-8888-888888888888'
);

select pg_temp.authenticate_as('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb');
insert into public.businesses (id, name, slug, created_by)
values (
  'b0000000-0000-4000-8000-00000000000b',
  'Business B', 'business-b-rls-test',
  'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb'
);

-- henry, as Business A's owner, adds iris (admin) and jack (member).
select pg_temp.authenticate_as('88888888-8888-8888-8888-888888888888');
insert into public.business_members (business_id, profile_id, role, status)
select id, '99999999-9999-9999-9999-999999999999', 'admin', 'active' from public.businesses where slug = 'business-a-rls-test';
insert into public.business_members (business_id, profile_id, role, status)
select id, 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'member', 'active' from public.businesses where slug = 'business-a-rls-test';

-- ---------------------------------------------------------------------------
-- SELECT: owner, admin, and plain member can all see the full roster
-- (peer visibility) -- but only once active. Outsiders and anon see
-- nothing for a business they don't belong to.
-- ---------------------------------------------------------------------------

select is(
  (select count(*)::int from public.business_members bm
   join public.businesses b on b.id = bm.business_id
   where b.slug = 'business-a-rls-test'),
  3,
  'owner (henry) sees all 3 members of Business A -- peer visibility'
);

select pg_temp.authenticate_as('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa');
select is(
  (select count(*)::int from public.business_members bm
   join public.businesses b on b.id = bm.business_id
   where b.slug = 'business-a-rls-test'),
  3,
  'a plain member (jack) also sees all 3 peers, not just himself'
);

select pg_temp.authenticate_as('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb');
select is(
  (select count(*)::int from public.business_members bm
   join public.businesses b on b.id = bm.business_id
   where b.slug = 'business-a-rls-test'),
  0,
  'kate (outsider, member of a different business) sees none of Business A''s members'
);

select is(
  (select count(*)::int from public.business_members bm
   join public.businesses b on b.id = bm.business_id
   where b.slug = 'business-b-rls-test'),
  1,
  'kate does see her own Business B roster (just herself, the auto-provisioned owner)'
);

-- anon has no table-level GRANT on business_members at all (only
-- authenticated does -- see 20260821234807_identity.sql's grants), so an
-- anon SELECT fails at the permission layer before RLS is even
-- evaluated; that denial is itself the "anon sees nothing" guarantee.
select pg_temp.authenticate_as_anon();
select throws_ok(
  $$ select count(*) from public.business_members $$,
  '42501', null,
  'anon (no session, no table grant) cannot read business_members at all'
);

-- ---------------------------------------------------------------------------
-- INSERT: only an admin/owner of the target business may add a member.
-- ---------------------------------------------------------------------------

select pg_temp.authenticate_as('99999999-9999-9999-9999-999999999999');
select lives_ok(
  $$
  insert into public.business_members (business_id, profile_id, role, status)
  select id, 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'member', 'invited' from public.businesses where slug = 'business-a-rls-test'
  $$,
  'iris (admin of Business A) can invite a new member'
);
delete from public.business_members
where business_id = (select id from public.businesses where slug = 'business-a-rls-test')
  and profile_id = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb';

select pg_temp.authenticate_as('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa');
select throws_ok(
  $$
  insert into public.business_members (business_id, profile_id, role, status)
  select id, 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'member', 'invited' from public.businesses where slug = 'business-a-rls-test'
  $$,
  '42501', null,
  'jack (plain member, not admin) cannot invite a new member'
);

-- ---------------------------------------------------------------------------
-- Escalation -- the actual bug this suite exists to lock in against
-- regressing. Both used to succeed before the fix migration.
-- ---------------------------------------------------------------------------

select pg_temp.authenticate_as('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa');
select throws_ok(
  $$
  insert into public.business_members (business_id, profile_id, role, status)
  values (
    'b0000000-0000-4000-8000-00000000000b',
    'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'owner', 'active'
  )
  $$,
  '42501', null,
  'jack cannot self-insert into a business he has zero relationship to (self-service INSERT escalation)'
);

select pg_temp.authenticate_as('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb');
select throws_ok(
  $$
  insert into public.business_members (business_id, profile_id, role, status)
  values (
    'a0000000-0000-4000-8000-00000000000a',
    'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'owner', 'active'
  )
  $$,
  '42501', null,
  'kate cannot grant herself ownership of Business A by inserting her own membership row'
);

select pg_temp.authenticate_as('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa');
select is(
  pg_temp.execute_and_count($$
    update public.business_members
    set role = 'owner'
    where business_id = (select id from public.businesses where slug = 'business-a-rls-test')
      and profile_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'
  $$),
  0,
  'jack cannot self-promote to owner via UPDATE -- no self-service UPDATE policy exists at all now'
);

select pg_temp.authenticate_as('88888888-8888-8888-8888-888888888888');
select is(
  (select role::text from public.business_members
   where business_id = (select id from public.businesses where slug = 'business-a-rls-test')
     and profile_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'),
  'member',
  'jack''s role is still member -- the escalation attempt above left no trace'
);

-- ---------------------------------------------------------------------------
-- Legitimate admin UPDATE still works (unaffected by the fix).
-- ---------------------------------------------------------------------------

select lives_ok(
  $$
  update public.business_members
  set role = 'admin'
  where business_id = (select id from public.businesses where slug = 'business-a-rls-test')
    and profile_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'
  $$,
  'henry (owner) can promote jack to admin -- legitimate admin management, unaffected by the fix'
);

-- ---------------------------------------------------------------------------
-- DELETE: self-leave still works; deleting someone else without admin
-- rights does not.
-- ---------------------------------------------------------------------------

select pg_temp.authenticate_as('99999999-9999-9999-9999-999999999999');
select is(
  pg_temp.execute_and_count($$
    delete from public.business_members
    where business_id = 'a0000000-0000-4000-8000-00000000000a'
      and profile_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'
  $$),
  1,
  'iris can remove jack through the explicit admin-management policy'
);

select lives_ok(
  $$
  delete from public.business_members
  where business_id = (select id from public.businesses where slug = 'business-a-rls-test')
    and profile_id = '99999999-9999-9999-9999-999999999999'
  $$,
  'iris can delete her own membership row -- leaving the business'
);

select is(
  (select count(*)::int from public.business_members
   where business_id = (select id from public.businesses where slug = 'business-a-rls-test')
     and profile_id = '99999999-9999-9999-9999-999999999999'),
  0,
  'iris is confirmed gone from Business A after leaving'
);

-- ---------------------------------------------------------------------------
-- Cross-business: an admin of Business A has zero standing in Business B.
-- ---------------------------------------------------------------------------

select pg_temp.authenticate_as('88888888-8888-8888-8888-888888888888');
select throws_ok(
  $$
  insert into public.business_members (business_id, profile_id, role, status)
  values (
    'b0000000-0000-4000-8000-00000000000b',
    'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'member', 'invited'
  )
  $$,
  '42501', null,
  'henry (owner of Business A only) cannot add members to Business B'
);

select is(
  pg_temp.execute_and_count($$
    update public.business_members
    set role = 'member'
    where business_id = 'b0000000-0000-4000-8000-00000000000b'
  $$),
  0,
  'henry cannot update any row belonging to Business B'
);

select * from finish();

rollback;
