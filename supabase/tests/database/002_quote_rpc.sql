-- pgTAP regression tests for public.create_quote_with_line_items
-- (supabase/migrations/20260817000008_quote_rpc.sql). Run with:
--   supabase test db --local supabase/tests/database

create extension if not exists pgtap;

begin;

select plan(5);

-- ---------------------------------------------------------------------------
-- Fixtures: one auth user + a contact to quote against.
-- ---------------------------------------------------------------------------

do $$
declare
  v_instance_id uuid := '00000000-0000-0000-0000-000000000000';
begin
  insert into auth.users (
    instance_id, id, aud, role, email, encrypted_password,
    email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
    created_at, updated_at
  ) values (
    v_instance_id, '33333333-3333-3333-3333-333333333333', 'authenticated', 'authenticated',
    'carol@test.local', crypt('password123', gen_salt('bf')), now(), '{}', '{}', now(), now()
  );
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

select pg_temp.authenticate_as('33333333-3333-3333-3333-333333333333');

insert into public.contacts (account_id, display_name)
select id, 'RPC Test Contact' from public.accounts
where owner_profile_id = '33333333-3333-3333-3333-333333333333';

-- ---------------------------------------------------------------------------
-- Success path: header + line items land atomically.
-- ---------------------------------------------------------------------------

select lives_ok(
  $$
  select public.create_quote_with_line_items(
    (select id from public.accounts where owner_profile_id = '33333333-3333-3333-3333-333333333333'),
    (select id from public.contacts where display_name = 'RPC Test Contact'),
    null,
    'Q-TEST-0001',
    9900, 0, 9900,
    '33333333-3333-3333-3333-333333333333',
    '[{"description":"Widget","quantity":3,"unit_price_cents":3300}]'::jsonb
  )
  $$,
  'create_quote_with_line_items succeeds with one valid line item'
);

select is(
  (select count(*)::int from public.quotes where quote_number = 'Q-TEST-0001'),
  1,
  'exactly one quote header was created'
);

select is(
  (select count(*)::int from public.quote_line_items qli
   join public.quotes q on q.id = qli.quote_id
   where q.quote_number = 'Q-TEST-0001'),
  1,
  'exactly one line item was created, linked to the new quote'
);

-- ---------------------------------------------------------------------------
-- Failure path: empty line items rejected, and no orphan header remains.
-- ---------------------------------------------------------------------------

select throws_ok(
  $$
  select public.create_quote_with_line_items(
    (select id from public.accounts where owner_profile_id = '33333333-3333-3333-3333-333333333333'),
    (select id from public.contacts where display_name = 'RPC Test Contact'),
    null,
    'Q-TEST-0002',
    0, 0, 0,
    '33333333-3333-3333-3333-333333333333',
    '[]'::jsonb
  )
  $$,
  'P0001',
  'create_quote_with_line_items: at least one line item is required',
  'empty line items array is rejected'
);

select is(
  (select count(*)::int from public.quotes where quote_number = 'Q-TEST-0002'),
  0,
  'the rejected call left no orphan quote header behind'
);

select * from finish();

rollback;
