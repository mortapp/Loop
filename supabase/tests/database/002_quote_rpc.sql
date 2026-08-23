-- pgTAP regression tests for public.create_quote_with_line_items
-- (supabase/migrations/20260821235124_quote_rpc.sql). Run with:
--   supabase test db --local supabase/tests/database

create extension if not exists pgtap;

begin;

select plan(13);

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

select throws_ok(
  $$
  select public.create_quote_with_line_items(
    (select id from public.accounts where owner_profile_id = '33333333-3333-3333-3333-333333333333'),
    (select id from public.contacts where display_name = 'RPC Test Contact'),
    null,
    'Q-TEST-0003',
    1, 0, 1,
    '33333333-3333-3333-3333-333333333333',
    '[{"description":"Widget","quantity":3,"unit_price_cents":3300}]'::jsonb
  )
  $$,
  '22023', null,
  'client totals must match the server-calculated line subtotal'
);

select is(
  (select count(*)::int from public.quotes where quote_number = 'Q-TEST-0003'),
  0,
  'a totals mismatch leaves no orphan quote header'
);

select throws_ok(
  $$
  select public.create_quote_with_line_items(
    (select id from public.accounts where owner_profile_id = '33333333-3333-3333-3333-333333333333'),
    (select id from public.contacts where display_name = 'RPC Test Contact'),
    null,
    'Q-TEST-0004',
    -100, 0, -100,
    '33333333-3333-3333-3333-333333333333',
    '[{"description":"Bad line","quantity":1,"unit_price_cents":-100}]'::jsonb
  )
  $$,
  '22023', null,
  'negative line prices are rejected by the RPC'
);

select is(
  (select count(*)::int from public.quotes where quote_number = 'Q-TEST-0004'),
  0,
  'an invalid line leaves no orphan quote header'
);

select lives_ok(
  $$
  select public.create_quote_with_line_items(
    (select id from public.accounts where owner_profile_id = '33333333-3333-3333-3333-333333333333'),
    (select id from public.contacts where display_name = 'RPC Test Contact'),
    null,
    'Q-TEST-0005',
    500, 0, 500,
    '99999999-9999-4999-8999-999999999999',
    '[{"description":"Actor test","quantity":1,"unit_price_cents":500}]'::jsonb
  )
  $$,
  'the legacy created-by parameter remains accepted'
);

select is(
  (select created_by from public.quotes where quote_number = 'Q-TEST-0005'),
  '33333333-3333-3333-3333-333333333333'::uuid,
  'the stored quote actor is derived from auth, not the RPC parameter'
);

select throws_ok(
  $$
  insert into public.quotes (
    account_id, contact_id, quote_number,
    subtotal_cents, tax_cents, total_cents
  )
  select id,
         (select id from public.contacts where display_name = 'RPC Test Contact'),
         'Q-DIRECT-BAD', 100, 0, 99
  from public.accounts
  where owner_profile_id = '33333333-3333-3333-3333-333333333333'
  $$,
  '23514', null,
  'direct quote writes cannot bypass amount consistency'
);

select throws_ok(
  $$
  insert into public.quote_line_items (
    quote_id, description, quantity, unit_price_cents
  )
  select id, 'Invalid quantity', 0, 100
  from public.quotes
  where quote_number = 'Q-TEST-0001'
  $$,
  '23514', null,
  'direct line writes cannot bypass quantity constraints'
);

select * from finish();

rollback;
