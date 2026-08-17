-- pgTAP regression tests for identity auto-provisioning and RLS
-- isolation. Run with: supabase test db --local supabase/tests/database
--
-- This encodes the manual REST/psql smoke test performed while building
-- 20260817000002_identity.sql (see docs/TEST_MATRIX.md /
-- docs/KNOWN_ISSUES.md), so the two real bugs found there (RLS
-- self-recursion, and the INSERT...RETURNING/SELECT-policy race on
-- business creation) can't silently regress.

create extension if not exists pgtap;

begin;

select plan(15);

-- ---------------------------------------------------------------------------
-- Fixtures: two auth users, inserted directly (as `supabase test db` has
-- no running GoTrue). This exercises the real on_auth_user_created trigger.
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
    (v_instance_id, '11111111-1111-1111-1111-111111111111', 'authenticated', 'authenticated',
     'alice@test.local', crypt('password123', gen_salt('bf')), now(), '{}', '{}', now(), now()),
    (v_instance_id, '22222222-2222-2222-2222-222222222222', 'authenticated', 'authenticated',
     'bob@test.local', crypt('password123', gen_salt('bf')), now(), '{}', '{}', now(), now());
end $$;

-- ---------------------------------------------------------------------------
-- Auto-provisioning: auth.users -> profiles -> personal account
-- ---------------------------------------------------------------------------

select is(
  (select count(*)::int from public.profiles where id = '11111111-1111-1111-1111-111111111111'),
  1,
  'signup auto-creates exactly one profile row'
);

select is(
  (select email from public.profiles where id = '11111111-1111-1111-1111-111111111111'),
  'alice@test.local',
  'profile email matches auth.users email'
);

select is(
  (select count(*)::int from public.accounts
   where owner_profile_id = '11111111-1111-1111-1111-111111111111' and type = 'personal'),
  1,
  'profile creation auto-creates exactly one personal account'
);

select is(
  (select count(*)::int from public.profiles where id = '22222222-2222-2222-2222-222222222222'),
  1,
  'second signup also auto-creates a profile row'
);

-- ---------------------------------------------------------------------------
-- Helper: switch the current transaction to act as a given auth user,
-- the same way PostgREST does (SET ROLE + request.jwt.claims).
-- ---------------------------------------------------------------------------

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

-- ---------------------------------------------------------------------------
-- Cross-account RLS isolation
-- ---------------------------------------------------------------------------

select pg_temp.authenticate_as('11111111-1111-1111-1111-111111111111');

select lives_ok(
  $$ insert into public.items (account_id, name)
     select id, 'Alice''s Laptop' from public.accounts
     where owner_profile_id = '11111111-1111-1111-1111-111111111111' $$,
  'alice can insert an item into her own personal account'
);

reset role;
select pg_temp.authenticate_as('22222222-2222-2222-2222-222222222222');

select is(
  (select count(*)::int from public.items),
  0,
  'bob cannot see alice''s items (RLS isolation)'
);

select is(
  (select count(*)::int from public.profiles where id = '11111111-1111-1111-1111-111111111111'),
  0,
  'bob cannot see alice''s profile (no shared business)'
);

-- ---------------------------------------------------------------------------
-- Business creation: regression test for the INSERT...RETURNING /
-- SELECT-policy race documented in docs/KNOWN_ISSUES.md.
-- ---------------------------------------------------------------------------

reset role;
select pg_temp.authenticate_as('11111111-1111-1111-1111-111111111111');

select lives_ok(
  $$ insert into public.businesses (name, slug, created_by)
     values ('Alice LLC', 'alice-llc-pgtap', '11111111-1111-1111-1111-111111111111')
     returning id $$,
  'alice can create a business and get it back via RETURNING (no RLS error)'
);

select is(
  (select count(*)::int from public.business_members bm
   join public.businesses b on b.id = bm.business_id
   where b.slug = 'alice-llc-pgtap'
     and bm.profile_id = '11111111-1111-1111-1111-111111111111'
     and bm.role = 'owner' and bm.status = 'active'),
  1,
  'business creation auto-provisions an active owner membership'
);

select is(
  (select count(*)::int from public.accounts a
   join public.businesses b on b.id = a.business_id
   where b.slug = 'alice-llc-pgtap' and a.type = 'business'),
  1,
  'business creation auto-provisions a business account'
);

reset role;
select pg_temp.authenticate_as('22222222-2222-2222-2222-222222222222');

select is(
  (select count(*)::int from public.businesses where slug = 'alice-llc-pgtap'),
  0,
  'bob cannot see alice''s business (not a member)'
);

-- ---------------------------------------------------------------------------
-- Append-only ledger: money_events is select+insert only, never mutable.
-- ---------------------------------------------------------------------------

reset role;
select pg_temp.authenticate_as('11111111-1111-1111-1111-111111111111');

select lives_ok(
  $$ insert into public.money_events (account_id, kind, amount_cents, description)
     select id, 'earn', 5000, 'pgtap test'
     from public.accounts
     where owner_profile_id = '11111111-1111-1111-1111-111111111111' $$,
  'alice can insert a money_event into her own account'
);

select throws_ok(
  $$ update public.money_events set amount_cents = 1
     where description = 'pgtap test' $$,
  '42501',
  null,
  'money_events cannot be updated (append-only ledger, no UPDATE grant)'
);

select throws_ok(
  $$ delete from public.money_events where description = 'pgtap test' $$,
  '42501',
  null,
  'money_events cannot be deleted (append-only ledger, no DELETE grant)'
);

reset role;

select is(
  (select count(*)::int from public.money_events where description = 'pgtap test'),
  1,
  'the money_event row survived the rejected update/delete attempts'
);

select * from finish();

rollback;
