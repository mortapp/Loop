-- pgTAP regression coverage for cross-account nested references and
-- server-derived actor identities.

create extension if not exists pgtap;

begin;

select plan(32);

do $$
declare
  v_instance_id uuid := '00000000-0000-0000-0000-000000000000';
begin
  insert into auth.users (
    instance_id, id, aud, role, email, encrypted_password,
    email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
    created_at, updated_at
  ) values
    (v_instance_id, '11111111-1111-4111-8111-111111111111', 'authenticated', 'authenticated',
     'graph-a@test.local', crypt('password123', gen_salt('bf')), now(), '{}', '{}', now(), now()),
    (v_instance_id, '22222222-2222-4222-8222-222222222222', 'authenticated', 'authenticated',
     'graph-b@test.local', crypt('password123', gen_salt('bf')), now(), '{}', '{}', now(), now());
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

-- Build a complete Account B graph using only Account B's authenticated
-- session. The fixed IDs are synthetic and the entire transaction rolls back.
select pg_temp.authenticate_as('22222222-2222-4222-8222-222222222222');

insert into public.contacts (id, account_id, display_name, created_by)
select 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb2', id, 'Account B contact',
       '22222222-2222-4222-8222-222222222222'
from public.accounts where owner_profile_id = '22222222-2222-4222-8222-222222222222';

insert into public.items (id, account_id, name, created_by)
select 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa2', id, 'Account B item',
       '22222222-2222-4222-8222-222222222222'
from public.accounts where owner_profile_id = '22222222-2222-4222-8222-222222222222';

insert into public.documents (
  id, account_id, item_id, storage_path, file_name, created_by
)
select 'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeee2', id,
       'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa2',
       id::text || '/fixture/document.pdf', 'document.pdf',
       '22222222-2222-4222-8222-222222222222'
from public.accounts where owner_profile_id = '22222222-2222-4222-8222-222222222222';

insert into public.leads (id, account_id, contact_id, created_by)
select 'cccccccc-cccc-4ccc-8ccc-ccccccccccc2', id,
       'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb2',
       '22222222-2222-4222-8222-222222222222'
from public.accounts where owner_profile_id = '22222222-2222-4222-8222-222222222222';

insert into public.opportunities (
  id, account_id, contact_id, lead_id, title, created_by
)
select 'dddddddd-dddd-4ddd-8ddd-ddddddddddd2', id,
       'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb2',
       'cccccccc-cccc-4ccc-8ccc-ccccccccccc2',
       'Account B opportunity',
       '22222222-2222-4222-8222-222222222222'
from public.accounts where owner_profile_id = '22222222-2222-4222-8222-222222222222';

insert into public.purchases (
  id, account_id, item_id, vendor_contact_id, receipt_document_id, created_by
)
select 'ffffffff-ffff-4fff-8fff-fffffffffff2', id,
       'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa2',
       'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb2',
       'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeee2',
       '22222222-2222-4222-8222-222222222222'
from public.accounts where owner_profile_id = '22222222-2222-4222-8222-222222222222';

insert into public.listings (id, account_id, item_id, marketplace, created_by)
select '99999999-9999-4999-8999-999999999992', id,
       'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa2', 'fixture',
       '22222222-2222-4222-8222-222222222222'
from public.accounts where owner_profile_id = '22222222-2222-4222-8222-222222222222';

-- Account A owns separate records and then attempts every forged edge.
select pg_temp.authenticate_as('11111111-1111-4111-8111-111111111111');

insert into public.contacts (id, account_id, display_name, created_by)
select 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb1', id, 'Account A contact',
       '11111111-1111-4111-8111-111111111111'
from public.accounts where owner_profile_id = '11111111-1111-4111-8111-111111111111';

insert into public.items (id, account_id, name, created_by)
select 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1', id, 'Account A item',
       '22222222-2222-4222-8222-222222222222'
from public.accounts where owner_profile_id = '11111111-1111-4111-8111-111111111111';

select throws_ok(
  $$ insert into public.documents (account_id, item_id, storage_path, file_name)
     select id, 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa2', id::text || '/x', 'x'
     from public.accounts where owner_profile_id = '11111111-1111-4111-8111-111111111111' $$,
  '23514', null, 'documents reject an item from another account'
);

select throws_ok(
  $$ insert into public.money_events (account_id, item_id, kind, amount_cents)
     select id, 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa2', 'spend', 100
     from public.accounts where owner_profile_id = '11111111-1111-4111-8111-111111111111' $$,
  '23514', null, 'money events reject an item from another account'
);

select throws_ok(
  $$ insert into public.leads (account_id, contact_id)
     select id, 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb2'
     from public.accounts where owner_profile_id = '11111111-1111-4111-8111-111111111111' $$,
  '23514', null, 'leads reject a contact from another account'
);

select throws_ok(
  $$ insert into public.opportunities (account_id, contact_id, title)
     select id, 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb2', 'forged'
     from public.accounts where owner_profile_id = '11111111-1111-4111-8111-111111111111' $$,
  '23514', null, 'opportunities reject a contact from another account'
);

select throws_ok(
  $$ insert into public.opportunities (account_id, lead_id, title)
     select id, 'cccccccc-cccc-4ccc-8ccc-ccccccccccc2', 'forged'
     from public.accounts where owner_profile_id = '11111111-1111-4111-8111-111111111111' $$,
  '23514', null, 'opportunities reject a lead from another account'
);

select throws_ok(
  $$ insert into public.quotes (account_id, contact_id, quote_number)
     select id, 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb2', 'FORGED-CONTACT'
     from public.accounts where owner_profile_id = '11111111-1111-4111-8111-111111111111' $$,
  '23514', null, 'quotes reject a contact from another account'
);

select throws_ok(
  $$ insert into public.quotes (account_id, opportunity_id, quote_number)
     select id, 'dddddddd-dddd-4ddd-8ddd-ddddddddddd2', 'FORGED-OPPORTUNITY'
     from public.accounts where owner_profile_id = '11111111-1111-4111-8111-111111111111' $$,
  '23514', null, 'quotes reject an opportunity from another account'
);

select throws_ok(
  $$ insert into public.purchases (account_id, item_id)
     select id, 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa2'
     from public.accounts where owner_profile_id = '11111111-1111-4111-8111-111111111111' $$,
  '23514', null, 'purchases reject an item from another account'
);

select throws_ok(
  $$ insert into public.purchases (account_id, vendor_contact_id)
     select id, 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb2'
     from public.accounts where owner_profile_id = '11111111-1111-4111-8111-111111111111' $$,
  '23514', null, 'purchases reject a vendor contact from another account'
);

select throws_ok(
  $$ insert into public.purchases (account_id, receipt_document_id)
     select id, 'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeee2'
     from public.accounts where owner_profile_id = '11111111-1111-4111-8111-111111111111' $$,
  '23514', null, 'purchases reject a receipt document from another account'
);

select throws_ok(
  $$ insert into public.returns (account_id, item_id)
     select id, 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa2'
     from public.accounts where owner_profile_id = '11111111-1111-4111-8111-111111111111' $$,
  '23514', null, 'returns reject an item from another account'
);

select throws_ok(
  $$ insert into public.returns (account_id, item_id, purchase_id)
     select id, 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1', 'ffffffff-ffff-4fff-8fff-fffffffffff2'
     from public.accounts where owner_profile_id = '11111111-1111-4111-8111-111111111111' $$,
  '23514', null, 'returns reject a purchase from another account'
);

select throws_ok(
  $$ insert into public.warranties (account_id, item_id)
     select id, 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa2'
     from public.accounts where owner_profile_id = '11111111-1111-4111-8111-111111111111' $$,
  '23514', null, 'warranties reject an item from another account'
);

select throws_ok(
  $$ insert into public.valuations (account_id, item_id, estimated_value_cents)
     select id, 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa2', 100
     from public.accounts where owner_profile_id = '11111111-1111-4111-8111-111111111111' $$,
  '23514', null, 'valuations reject an item from another account'
);

select throws_ok(
  $$ insert into public.listings (account_id, item_id, marketplace)
     select id, 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa2', 'fixture'
     from public.accounts where owner_profile_id = '11111111-1111-4111-8111-111111111111' $$,
  '23514', null, 'listings reject an item from another account'
);

select throws_ok(
  $$ insert into public.sales (account_id, item_id, sale_price_cents, net_amount_cents)
     select id, 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa2', 100, 100
     from public.accounts where owner_profile_id = '11111111-1111-4111-8111-111111111111' $$,
  '23514', null, 'sales reject an item from another account'
);

select throws_ok(
  $$ insert into public.sales (account_id, item_id, listing_id, sale_price_cents, net_amount_cents)
     select id, 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1', '99999999-9999-4999-8999-999999999992', 100, 100
     from public.accounts where owner_profile_id = '11111111-1111-4111-8111-111111111111' $$,
  '23514', null, 'sales reject a listing from another account'
);

select throws_ok(
  $$ insert into public.sales (account_id, item_id, buyer_contact_id, sale_price_cents, net_amount_cents)
     select id, 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1', 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb2', 100, 100
     from public.accounts where owner_profile_id = '11111111-1111-4111-8111-111111111111' $$,
  '23514', null, 'sales reject a buyer contact from another account'
);

select throws_ok(
  $$ insert into public.actions (account_id, type, title, assigned_to)
     select id, 'fixture', 'forged assignee', '22222222-2222-4222-8222-222222222222'
     from public.accounts where owner_profile_id = '11111111-1111-4111-8111-111111111111' $$,
  '23514', null, 'actions reject an assignee without account access'
);

select is(
  (select created_by from public.items where id = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1'),
  '11111111-1111-4111-8111-111111111111'::uuid,
  'insert actor is stamped from auth instead of trusting the payload'
);

update public.items
set created_by = '22222222-2222-4222-8222-222222222222'
where id = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1';

select is(
  (select created_by from public.items where id = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1'),
  '11111111-1111-4111-8111-111111111111'::uuid,
  'update cannot rewrite the original actor'
);

insert into public.events (account_id, type, actor_profile_id)
select id, 'fixture', '22222222-2222-4222-8222-222222222222'
from public.accounts where owner_profile_id = '11111111-1111-4111-8111-111111111111';

select is(
  (select actor_profile_id from public.events where type = 'fixture'),
  '11111111-1111-4111-8111-111111111111'::uuid,
  'event actor is stamped from auth instead of trusting the payload'
);

select lives_ok(
  $$ insert into public.documents (account_id, item_id, storage_path, file_name)
     select id, 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1', id::text || '/owned', 'owned'
     from public.accounts where owner_profile_id = '11111111-1111-4111-8111-111111111111' $$,
  'same-account references continue to work'
);

select throws_ok(
  $$ update public.profiles set email = 'spoofed@test.local'
     where id = '11111111-1111-4111-8111-111111111111' $$,
  '42501', null, 'profile email is not client-editable'
);

select lives_ok(
  $$ select public.create_quote_with_line_items(
       (select id from public.accounts where owner_profile_id = '11111111-1111-4111-8111-111111111111'),
       'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb1', null::uuid, 'OWN-RPC',
       100, 0, 100, '22222222-2222-4222-8222-222222222222',
       '[{"description":"Fixture","quantity":1,"unit_price_cents":100}]'::jsonb
     ) $$,
  'quote RPC still accepts its existing payload shape'
);

select is(
  (select created_by from public.quotes where quote_number = 'OWN-RPC'),
  '11111111-1111-4111-8111-111111111111'::uuid,
  'quote RPC cannot forge created_by'
);

select throws_ok(
  $$ select public.create_quote_with_line_items(
       (select id from public.accounts where owner_profile_id = '11111111-1111-4111-8111-111111111111'),
       'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb2', null::uuid, 'FORGED-RPC',
       100, 0, 100, '11111111-1111-4111-8111-111111111111',
       '[{"description":"Fixture","quantity":1,"unit_price_cents":100}]'::jsonb
     ) $$,
  '23514', null, 'quote RPC rejects a cross-account contact'
);

reset role;

select ok(
  not has_function_privilege(
    'anon',
    'public.create_quote_with_line_items(uuid,uuid,uuid,text,bigint,bigint,bigint,uuid,jsonb)',
    'EXECUTE'
  ),
  'anon cannot execute the quote RPC'
);

select ok(
  has_function_privilege(
    'authenticated',
    'public.create_quote_with_line_items(uuid,uuid,uuid,text,bigint,bigint,bigint,uuid,jsonb)',
    'EXECUTE'
  ),
  'authenticated retains quote RPC access'
);

select ok(
  not has_function_privilege('anon', 'public.rls_auto_enable()', 'EXECUTE'),
  'anon cannot execute the platform RLS event-trigger function'
);

select ok(
  not has_function_privilege('authenticated', 'public.rls_auto_enable()', 'EXECUTE'),
  'authenticated cannot execute the platform RLS event-trigger function'
);

select ok(
  not has_function_privilege(
    'authenticated', 'private.enforce_same_account_reference()', 'EXECUTE'
  ),
  'account-integrity trigger function has no client RPC surface'
);

select * from finish();

rollback;
