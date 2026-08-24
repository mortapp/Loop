create extension if not exists pgtap;

begin;

select plan(7);

insert into auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at
) values (
  '00000000-0000-0000-0000-000000000000',
  'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
  'authenticated', 'authenticated', 'money-bounds@test.local',
  crypt('password123', gen_salt('bf')), now(), '{}', '{}', now(), now()
);

set local role authenticated;
select set_config(
  'request.jwt.claims',
  json_build_object(
    'sub', 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
    'role', 'authenticated'
  )::text,
  true
);

select lives_ok(
  $$
  insert into public.money_events (
    account_id, kind, amount_cents, source_type, source_id
  )
  select id, 'earn', 100000000000, 'manual',
         '11111111-1111-4111-8111-111111111111'
  from public.accounts
  where owner_profile_id = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb'
  $$,
  'the maximum manual ledger amount is accepted'
);

select throws_ok(
  $$
  insert into public.money_events (account_id, kind, amount_cents)
  select id, 'earn', 100000000001
  from public.accounts
  where owner_profile_id = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb'
  $$,
  '23514', null,
  'a modified client cannot exceed the ledger amount bound'
);

select lives_ok(
  $$
  insert into public.opportunities (account_id, title, estimated_value_cents)
  select id, 'Zero estimate', 0
  from public.accounts
  where owner_profile_id = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb'
  $$,
  'an explicit zero opportunity estimate remains valid'
);

select throws_ok(
  $$
  insert into public.opportunities (account_id, title, estimated_value_cents)
  select id, 'Negative estimate', -1
  from public.accounts
  where owner_profile_id = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb'
  $$,
  '23514', null,
  'negative opportunity estimates are rejected server-side'
);

select throws_ok(
  $$
  insert into public.opportunities (account_id, title, estimated_value_cents)
  select id, 'Oversized estimate', 100000000001
  from public.accounts
  where owner_profile_id = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb'
  $$,
  '23514', null,
  'oversized opportunity estimates are rejected server-side'
);

select throws_ok(
  $$
  insert into public.money_events (
    account_id, kind, amount_cents, source_type, source_id
  )
  select id, 'earn', 100000000000, 'manual',
         '11111111-1111-4111-8111-111111111111'
  from public.accounts
  where owner_profile_id = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb'
  $$,
  '23505', null,
  'a retried manual request cannot duplicate a ledger row'
);

select throws_ok(
  $$
  insert into public.money_events (
    account_id, kind, amount_cents, source_type, source_id
  )
  select id, 'spend', 1, 'manual',
         '11111111-1111-4111-8111-111111111111'
  from public.accounts
  where owner_profile_id = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb'
  $$,
  '23505', null,
  'a request identity cannot be reused with a different payload'
);

select * from finish();

rollback;
