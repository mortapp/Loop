-- pgTAP coverage for retry-safe AI confirmation writes.

create extension if not exists pgtap;

begin;

select plan(6);

do $$
declare
  v_instance_id uuid := '00000000-0000-0000-0000-000000000000';
begin
  insert into auth.users (
    instance_id, id, aud, role, email, encrypted_password,
    email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
    created_at, updated_at
  ) values (
    v_instance_id, 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaa10',
    'authenticated', 'authenticated', 'ai-confirm@test.local',
    crypt('password123', gen_salt('bf')), now(), '{}', '{}', now(), now()
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

select pg_temp.authenticate_as('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaa10');

select has_index(
  'public', 'actions', 'actions_ai_confirmation_idempotency_idx',
  'actions have an AI confirmation idempotency index'
);

select has_index(
  'public', 'money_events', 'money_events_ai_confirmation_idempotency_idx',
  'money events have an AI confirmation idempotency index'
);

insert into public.actions (
  account_id, type, title, related_type, related_id, created_by
)
select id, 'ai', 'Follow up', 'ai_confirmation',
       '11111111-1111-4111-8111-111111111111',
       'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaa10'
from public.accounts
where owner_profile_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaa10';

select throws_ok(
  $$
  insert into public.actions (
    account_id, type, title, related_type, related_id, created_by
  )
  select id, 'ai', 'Follow up', 'ai_confirmation',
         '11111111-1111-4111-8111-111111111111',
         'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaa10'
  from public.accounts
  where owner_profile_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaa10'
  $$,
  '23505', null,
  'repeating an approved AI action cannot create a second action'
);

insert into public.money_events (
  account_id, kind, amount_cents, source_type, source_id, created_by
)
select id, 'earn', 2500, 'ai',
       '22222222-2222-4222-8222-222222222222',
       'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaa10'
from public.accounts
where owner_profile_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaa10';

select throws_ok(
  $$
  insert into public.money_events (
    account_id, kind, amount_cents, source_type, source_id, created_by
  )
  select id, 'earn', 2500, 'ai',
         '22222222-2222-4222-8222-222222222222',
         'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaa10'
  from public.accounts
  where owner_profile_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaa10'
  $$,
  '23505', null,
  'repeating an approved AI money event cannot create a second event'
);

select is(
  (select count(*) from public.actions
   where related_type = 'ai_confirmation'
     and related_id = '11111111-1111-4111-8111-111111111111'),
  1::bigint,
  'the first AI action remains present exactly once'
);

select is(
  (select count(*) from public.money_events
   where source_type = 'ai'
     and source_id = '22222222-2222-4222-8222-222222222222'),
  1::bigint,
  'the first AI money event remains present exactly once'
);

select * from finish();

rollback;
