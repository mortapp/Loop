-- pgTAP coverage for account-scoped, retry-safe item photo metadata updates.

create extension if not exists pgtap;

begin;

select plan(13);

do $$
declare
  v_instance_id uuid := '00000000-0000-0000-0000-000000000000';
begin
  insert into auth.users (
    instance_id, id, aud, role, email, encrypted_password,
    email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
    created_at, updated_at
  ) values
    (v_instance_id, 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaa11',
     'authenticated', 'authenticated', 'photos-a@test.local',
     crypt('password123', gen_salt('bf')), now(), '{}', '{}', now(), now()),
    (v_instance_id, 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbb11',
     'authenticated', 'authenticated', 'photos-b@test.local',
     crypt('password123', gen_salt('bf')), now(), '{}', '{}', now(), now());

  update public.accounts
  set id = '33333333-3333-4333-8333-333333333311'
  where owner_profile_id = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaa11';

  update public.accounts
  set id = '44444444-4444-4444-8444-444444444411'
  where owner_profile_id = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbb11';
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

select pg_temp.authenticate_as('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaa11');

insert into public.items (id, account_id, name, created_by)
values (
  '55555555-5555-4555-8555-555555555511',
  '33333333-3333-4333-8333-333333333311',
  'Photo fixture',
  'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaa11'
);

insert into storage.objects (bucket_id, name)
values
  ('item-photos',
   '33333333-3333-4333-8333-333333333311/55555555-5555-4555-8555-555555555511/one.jpg'),
  ('item-photos',
   '33333333-3333-4333-8333-333333333311/55555555-5555-4555-8555-555555555511/two.jpg');

select is(
  public.attach_item_photo(
    '33333333-3333-4333-8333-333333333311',
    '55555555-5555-4555-8555-555555555511',
    '33333333-3333-4333-8333-333333333311/55555555-5555-4555-8555-555555555511/one.jpg'
  ),
  array['33333333-3333-4333-8333-333333333311/55555555-5555-4555-8555-555555555511/one.jpg'],
  'the first uploaded object is attached'
);

select is(
  cardinality(public.attach_item_photo(
    '33333333-3333-4333-8333-333333333311',
    '55555555-5555-4555-8555-555555555511',
    '33333333-3333-4333-8333-333333333311/55555555-5555-4555-8555-555555555511/one.jpg'
  )),
  1,
  'an exact attachment retry is idempotent'
);

select is(
  cardinality(public.attach_item_photo(
    '33333333-3333-4333-8333-333333333311',
    '55555555-5555-4555-8555-555555555511',
    '33333333-3333-4333-8333-333333333311/55555555-5555-4555-8555-555555555511/two.jpg'
  )),
  2,
  'a second attachment preserves the first path'
);

select is(
  cardinality(public.detach_item_photo(
    '33333333-3333-4333-8333-333333333311',
    '55555555-5555-4555-8555-555555555511',
    '33333333-3333-4333-8333-333333333311/55555555-5555-4555-8555-555555555511/one.jpg'
  )),
  1,
  'detaching one path preserves a concurrent second path'
);

select is(
  cardinality(public.detach_item_photo(
    '33333333-3333-4333-8333-333333333311',
    '55555555-5555-4555-8555-555555555511',
    '33333333-3333-4333-8333-333333333311/55555555-5555-4555-8555-555555555511/one.jpg'
  )),
  1,
  'an exact detach retry is idempotent'
);

select throws_ok(
  $$
  select public.attach_item_photo(
    '33333333-3333-4333-8333-333333333311',
    '55555555-5555-4555-8555-555555555511',
    '33333333-3333-4333-8333-333333333311/66666666-6666-4666-8666-666666666611/one.jpg'
  )
  $$,
  '22023', 'invalid item photo path',
  'a path for another item is rejected'
);

select throws_ok(
  $$
  select public.attach_item_photo(
    '33333333-3333-4333-8333-333333333311',
    '55555555-5555-4555-8555-555555555511',
    '33333333-3333-4333-8333-333333333311/55555555-5555-4555-8555-555555555511/missing.jpg'
  )
  $$,
  '23503', 'item photo object not found',
  'metadata cannot reference a missing Storage object'
);

select pg_temp.authenticate_as('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbb11');

select throws_ok(
  $$
  select public.attach_item_photo(
    '33333333-3333-4333-8333-333333333311',
    '55555555-5555-4555-8555-555555555511',
    '33333333-3333-4333-8333-333333333311/55555555-5555-4555-8555-555555555511/one.jpg'
  )
  $$,
  '42501', 'account access denied',
  'another account cannot attach a private photo'
);

select is(
  (
    select count(*)
    from pg_proc as proc
    join pg_namespace as namespace on namespace.oid = proc.pronamespace
    where namespace.nspname = 'public'
      and proc.proname in ('attach_item_photo', 'detach_item_photo')
      and proc.prosecdef
  ),
  0::bigint,
  'item photo functions run with invoker rights'
);

select is(
  has_function_privilege(
    'anon', 'public.attach_item_photo(uuid, uuid, text)', 'execute'
  ),
  false,
  'anonymous callers cannot attach item photos'
);

select is(
  has_function_privilege(
    'anon', 'public.detach_item_photo(uuid, uuid, text)', 'execute'
  ),
  false,
  'anonymous callers cannot detach item photos'
);

select is(
  has_function_privilege(
    'authenticated', 'public.attach_item_photo(uuid, uuid, text)', 'execute'
  ),
  true,
  'authenticated callers can use the attach RPC through RLS'
);

select is(
  has_function_privilege(
    'authenticated', 'public.detach_item_photo(uuid, uuid, text)', 'execute'
  ),
  true,
  'authenticated callers can use the detach RPC through RLS'
);

select * from finish();

rollback;
