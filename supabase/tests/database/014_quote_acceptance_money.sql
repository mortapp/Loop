create extension if not exists pgtap;

begin;

select plan(9);

insert into auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at
) values
(
  '00000000-0000-0000-0000-000000000000',
  'e1000000-0000-4000-8000-000000000001',
  'authenticated', 'authenticated', 'quote-owner@test.local',
  crypt('password123', gen_salt('bf')), now(), '{}', '{}', now(), now()
),
(
  '00000000-0000-0000-0000-000000000000',
  'e1000000-0000-4000-8000-000000000002',
  'authenticated', 'authenticated', 'quote-outsider@test.local',
  crypt('password123', gen_salt('bf')), now(), '{}', '{}', now(), now()
);

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

select pg_temp.authenticate_as('e1000000-0000-4000-8000-000000000001');

insert into public.contacts (account_id, display_name)
select id, 'Acceptance Test Contact'
from public.accounts
where owner_profile_id = 'e1000000-0000-4000-8000-000000000001';

select lives_ok(
  $$ select public.create_quote_with_line_items(
    (select id from public.accounts where owner_profile_id = 'e1000000-0000-4000-8000-000000000001'),
    (select id from public.contacts where display_name = 'Acceptance Test Contact'),
    null, 'Q-ACCEPTANCE-1', 1234, 0, 1234,
    'e1000000-0000-4000-8000-000000000001',
    '[{"description":"Acceptance test","quantity":1,"unit_price_cents":1234}]'::jsonb
  ) $$,
  'a paid quote is created through the validated RPC'
);

select lives_ok(
  $$ select public.set_quote_status_with_money_event(
    (select id from public.quotes where quote_number = 'Q-ACCEPTANCE-1'),
    'accepted'
  ) $$,
  'an authorized member can atomically accept a quote'
);

select is(
  (select status::text from public.quotes where quote_number = 'Q-ACCEPTANCE-1'),
  'accepted',
  'the quote status is accepted'
);

select ok(
  (select accepted_at is not null from public.quotes where quote_number = 'Q-ACCEPTANCE-1'),
  'the existing status trigger stamps accepted_at'
);

select is(
  (select count(*)::int
     from public.money_events as event
     join public.quotes as quote on quote.id = event.source_id
    where quote.quote_number = 'Q-ACCEPTANCE-1'
      and event.source_type = 'quote'
      and event.kind = 'earn'),
  1,
  'acceptance creates exactly one quote earn event'
);

select is(
  (select event.amount_cents
     from public.money_events as event
     join public.quotes as quote on quote.id = event.source_id
    where quote.quote_number = 'Q-ACCEPTANCE-1'
      and event.source_type = 'quote'
      and event.kind = 'earn'),
  1234::bigint,
  'the server derives the ledger amount from the stored quote total'
);

select lives_ok(
  $$ select public.set_quote_status_with_money_event(
    (select id from public.quotes where quote_number = 'Q-ACCEPTANCE-1'),
    'accepted'
  ) $$,
  'repeating acceptance is idempotent'
);

select is(
  (select count(*)::int
     from public.money_events as event
     join public.quotes as quote on quote.id = event.source_id
    where quote.quote_number = 'Q-ACCEPTANCE-1'
      and event.source_type = 'quote'
      and event.kind = 'earn'),
  1,
  'repeating acceptance cannot duplicate the ledger event'
);

select pg_temp.authenticate_as('e1000000-0000-4000-8000-000000000002');

select throws_ok(
  $$ select public.set_quote_status_with_money_event(
    (select id from public.quotes where quote_number = 'Q-ACCEPTANCE-1'),
    'declined'
  ) $$,
  '42501', null,
  'an unrelated account cannot change or monetize the quote'
);

select * from finish();

rollback;
