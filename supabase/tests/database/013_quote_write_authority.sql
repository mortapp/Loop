create extension if not exists pgtap;

begin;

select plan(8);

insert into auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at
) values (
  '00000000-0000-0000-0000-000000000000',
  'd1000000-0000-4000-8000-000000000001',
  'authenticated', 'authenticated', 'quote-authority@test.local',
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

select pg_temp.authenticate_as('d1000000-0000-4000-8000-000000000001');

insert into public.contacts (account_id, display_name)
select id, 'Quote Authority Contact'
from public.accounts
where owner_profile_id = 'd1000000-0000-4000-8000-000000000001';

select lives_ok(
  $$ select public.create_quote_with_line_items(
    (select id from public.accounts where owner_profile_id = 'd1000000-0000-4000-8000-000000000001'),
    (select id from public.contacts where display_name = 'Quote Authority Contact'),
    null, 'Q-AUTHORITY-1', 1234, 0, 1234,
    'd1000000-0000-4000-8000-000000000001',
    '[{"description":"Validated line","quantity":1,"unit_price_cents":1234}]'::jsonb
  ) $$,
  'the validated quote RPC still creates a quote after direct writes are revoked'
);

select throws_ok(
  $$ insert into public.quotes (
    account_id, contact_id, quote_number, subtotal_cents, tax_cents, total_cents
  ) select account_id, id, 'Q-DIRECT-VALID', 1234, 0, 1234
    from public.contacts where display_name = 'Quote Authority Contact' $$,
  '42501', null,
  'authenticated clients cannot insert quote headers directly'
);

select throws_ok(
  $$ update public.quotes set subtotal_cents = 1, total_cents = 1
     where quote_number = 'Q-AUTHORITY-1' $$,
  '42501', null,
  'authenticated clients cannot rewrite quote totals directly'
);

select throws_ok(
  $$ update public.quote_line_items set unit_price_cents = 1
     where quote_id = (select id from public.quotes where quote_number = 'Q-AUTHORITY-1') $$,
  '42501', null,
  'authenticated clients cannot rewrite quote lines directly'
);

select throws_ok(
  $$ update public.quotes set status = 'sent'
     where quote_number = 'Q-AUTHORITY-1' $$,
  '42501', null,
  'authenticated clients cannot bypass the atomic status RPC'
);

select lives_ok(
  $$ select public.set_quote_status_with_money_event(
    (select id from public.quotes where quote_number = 'Q-AUTHORITY-1'),
    'sent'
  ) $$,
  'authenticated account members retain the validated status path'
);

select ok(
  (select sent_at is not null from public.quotes where quote_number = 'Q-AUTHORITY-1'),
  'the server stamps sent_at when status becomes sent'
);

select throws_ok(
  $$ delete from public.quotes where quote_number = 'Q-AUTHORITY-1' $$,
  '42501', null,
  'authenticated clients cannot delete quote history directly'
);

select * from finish();

rollback;
