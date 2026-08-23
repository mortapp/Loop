-- pgTAP regression tests for @username handles
-- (supabase/migrations/20260822180000_usernames.sql). Run with:
--   supabase test db --local supabase/tests/database

create extension if not exists pgtap;

begin;

select plan(11);

do $$
declare
  v_instance_id uuid := '00000000-0000-0000-0000-000000000000';
begin
  insert into auth.users (
    instance_id, id, aud, role, email, encrypted_password,
    email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
    created_at, updated_at
  ) values
    (v_instance_id, 'cccccccc-cccc-cccc-cccc-cccccccccccc', 'authenticated', 'authenticated',
     'liam@test.local', crypt('password123', gen_salt('bf')), now(), '{}', '{}', now(), now()),
    (v_instance_id, 'dddddddd-dddd-dddd-dddd-dddddddddddd', 'authenticated', 'authenticated',
     'mia@test.local', crypt('password123', gen_salt('bf')), now(), '{}', '{}', now(), now());
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

select pg_temp.authenticate_as('cccccccc-cccc-cccc-cccc-cccccccccccc');

-- ---------------------------------------------------------------------------
-- Availability pre-check
-- ---------------------------------------------------------------------------

select ok(
  public.is_username_available('liamkurta'),
  'a well-formed, unused, non-reserved username is available'
);

select ok(
  not public.is_username_available('admin'),
  'a reserved name is not available'
);

select ok(
  not public.is_username_available('ab'),
  'a too-short candidate is not available'
);

select ok(
  not public.is_username_available('Liam-Kurta'),
  'a candidate with disallowed characters/case is not available'
);

-- ---------------------------------------------------------------------------
-- Claiming a username: format, reservation, and uniqueness are all real
-- schema constraints, not just the pre-check function.
-- ---------------------------------------------------------------------------

select lives_ok(
  $$ update public.profiles set username = 'liamkurta' where id = 'cccccccc-cccc-cccc-cccc-cccccccccccc' $$,
  'a well-formed username can be claimed'
);

select is(
  (select username from public.profiles where id = 'cccccccc-cccc-cccc-cccc-cccccccccccc'),
  'liamkurta',
  'the username was actually stored'
);

select throws_ok(
  $$ update public.profiles set username = 'admin' where id = 'cccccccc-cccc-cccc-cccc-cccccccccccc' $$,
  '23514',
  'a reserved name is rejected by the schema, not just the pre-check'
);

select throws_ok(
  $$ update public.profiles set username = 'ab' where id = 'cccccccc-cccc-cccc-cccc-cccccccccccc' $$,
  '23514',
  'a too-short username is rejected by the schema'
);

select throws_ok(
  $$ update public.profiles set username = 'Has-Dashes' where id = 'cccccccc-cccc-cccc-cccc-cccccccccccc' $$,
  '23514',
  'an out-of-character-set username is rejected by the schema'
);

-- mia tries to claim the same handle liam already has.
select pg_temp.authenticate_as('dddddddd-dddd-dddd-dddd-dddddddddddd');

select ok(
  not public.is_username_available('liamkurta'),
  'a taken username is reported unavailable'
);

select throws_ok(
  $$ update public.profiles set username = 'liamkurta' where id = 'dddddddd-dddd-dddd-dddd-dddddddddddd' $$,
  '23505',
  'the unique index rejects a second user claiming the same username -- database-authoritative, not just the pre-check'
);

select * from finish();

rollback;
