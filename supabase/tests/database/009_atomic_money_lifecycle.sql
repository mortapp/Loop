-- pgTAP regression coverage for atomic PROTECT/RECOVER lifecycle APIs.

create extension if not exists pgtap;

begin;

select plan(38);

do $$
declare
  v_instance_id uuid := '00000000-0000-0000-0000-000000000000';
begin
  insert into auth.users (
    instance_id, id, aud, role, email, encrypted_password,
    email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
    created_at, updated_at
  ) values
    (v_instance_id, 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa1', 'authenticated', 'authenticated',
     'lifecycle-a@test.local', crypt('password123', gen_salt('bf')), now(), '{}', '{}', now(), now()),
    (v_instance_id, 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa2', 'authenticated', 'authenticated',
     'lifecycle-b@test.local', crypt('password123', gen_salt('bf')), now(), '{}', '{}', now(), now());
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

create temporary table lifecycle_ids (
  key text primary key,
  id uuid not null
);

grant select, insert, update, delete on lifecycle_ids to authenticated;

select pg_temp.authenticate_as('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa1');

insert into public.items (id, account_id, name)
select '11111111-1111-1111-1111-111111111101', id, 'Sale item'
from public.accounts
where owner_profile_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa1';

insert into public.items (id, account_id, name)
select '11111111-1111-1111-1111-111111111102', id, 'Return item'
from public.accounts
where owner_profile_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa1';

insert into public.items (id, account_id, name)
select '11111111-1111-1111-1111-111111111103', id, 'Other item'
from public.accounts
where owner_profile_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa1';

-- A purchase and its spend event commit together through one RPC.
insert into lifecycle_ids (key, id)
select 'priced_purchase', public.create_purchase_with_money_event(
  id,
  '11111111-1111-1111-1111-111111111101',
  'Fixture Store',
  current_date,
  2500,
  current_date + 30,
  current_date + 365
)
from public.accounts
where owner_profile_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa1';

select is(
  (select count(*) from public.money_events
   where source_type = 'purchase'
     and source_id = (select id from lifecycle_ids where key = 'priced_purchase')),
  1::bigint,
  'a priced purchase creates exactly one sourced ledger event'
);

select is(
  (select kind::text from public.money_events
   where source_id = (select id from lifecycle_ids where key = 'priced_purchase')),
  'spend',
  'the purchase event is a spend'
);

select is(
  (select amount_cents from public.money_events
   where source_id = (select id from lifecycle_ids where key = 'priced_purchase')),
  2500::bigint,
  'the purchase event uses the exact integer-cent price'
);

select is(
  (select created_by from public.money_events
   where source_id = (select id from lifecycle_ids where key = 'priced_purchase')),
  'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa1'::uuid,
  'the purchase event actor is derived from Auth'
);

insert into lifecycle_ids (key, id)
select 'unpriced_purchase', public.create_purchase_with_money_event(
  id,
  '11111111-1111-1111-1111-111111111102',
  null,
  null,
  null,
  null,
  null
)
from public.accounts
where owner_profile_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa1';

select is(
  (select count(*) from public.money_events
   where source_id = (select id from lifecycle_ids where key = 'unpriced_purchase')),
  0::bigint,
  'a purchase without a price does not invent a money event'
);

select throws_ok(
  $$
  insert into public.purchases (account_id, item_id, price_cents)
  select id, '11111111-1111-1111-1111-111111111103', -1
  from public.accounts
  where owner_profile_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa1'
  $$,
  '23514', null,
  'negative purchase prices are rejected'
);

select throws_ok(
  $$
  update public.purchases
  set price_cents = 2600
  where id = (select id from lifecycle_ids where key = 'priced_purchase')
  $$,
  '23514', 'purchase financial identity is immutable',
  'a purchase cannot be detached from its append-only spend event'
);

-- Listing creation atomically marks the item listed.
insert into lifecycle_ids (key, id)
select 'listing', public.create_listing_and_mark_item(
  id,
  '11111111-1111-1111-1111-111111111101',
  'Fixture Market',
  1200
)
from public.accounts
where owner_profile_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa1';

select is(
  (select status::text from public.items
   where id = '11111111-1111-1111-1111-111111111101'),
  'listed',
  'creating a listing marks the item listed in the same transaction'
);

select throws_ok(
  $$
  insert into public.listings (account_id, item_id, marketplace)
  select id, '11111111-1111-1111-1111-111111111103', '   '
  from public.accounts
  where owner_profile_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa1'
  $$,
  '23514', null,
  'blank marketplace names are rejected'
);

-- One sale RPC drives item/listing state and gross/fee ledger entries.
insert into lifecycle_ids (key, id)
select 'sale', public.record_item_sale(
  id,
  '11111111-1111-1111-1111-111111111101',
  (select id from lifecycle_ids where key = 'listing'),
  1000,
  100
)
from public.accounts
where owner_profile_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa1';

select is(
  (select status::text from public.items
   where id = '11111111-1111-1111-1111-111111111101'),
  'sold',
  'recording a sale marks the item sold'
);

select is(
  (select status::text from public.listings
   where id = (select id from lifecycle_ids where key = 'listing')),
  'sold',
  'recording a sale closes its listing'
);

select is(
  (select amount_cents from public.money_events
   where source_id = (select id from lifecycle_ids where key = 'sale')
     and kind = 'recovered'),
  1000::bigint,
  'the recovered ledger bucket records the gross sale price'
);

select is(
  (select amount_cents from public.money_events
   where source_id = (select id from lifecycle_ids where key = 'sale')
     and kind = 'fee'),
  100::bigint,
  'the fee ledger bucket records sale fees separately'
);

select is(
  (select
     coalesce(sum(amount_cents) filter (where kind = 'recovered'), 0)
     - coalesce(sum(amount_cents) filter (where kind = 'fee'), 0)
   from public.money_events
   where source_id = (select id from lifecycle_ids where key = 'sale')),
  900::numeric,
  'gross minus fees agrees with the stored sale net'
);

select throws_ok(
  $$
  insert into public.sales (
    account_id, item_id, sale_price_cents, fees_cents, net_amount_cents
  )
  select id, '11111111-1111-1111-1111-111111111101', 1000, 0, 1000
  from public.accounts
  where owner_profile_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa1'
  $$,
  '23514', 'item cannot be sold in its current state',
  'a sold item cannot be sold again'
);

select throws_ok(
  $$
  insert into public.sales (
    account_id, item_id, sale_price_cents, fees_cents, net_amount_cents
  )
  select id, '11111111-1111-1111-1111-111111111103', 500, 600, -100
  from public.accounts
  where owner_profile_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa1'
  $$,
  '23514', null,
  'fees cannot exceed the sale price'
);

select throws_ok(
  $$
  insert into public.sales (
    account_id, item_id, listing_id,
    sale_price_cents, fees_cents, net_amount_cents
  )
  select id,
         '11111111-1111-1111-1111-111111111103',
         (select id from lifecycle_ids where key = 'listing'),
         500, 0, 500
  from public.accounts
  where owner_profile_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa1'
  $$,
  '23503', 'sale listing does not belong to the item',
  'a same-account listing cannot be paired with the wrong item'
);

-- Return transitions are guarded and refunds are idempotently ledgered.
insert into public.returns (
  id, account_id, item_id, purchase_id, reason
)
select
  '55555555-5555-5555-5555-555555555501',
  id,
  '11111111-1111-1111-1111-111111111102',
  (select id from lifecycle_ids where key = 'unpriced_purchase'),
  'Fixture return'
from public.accounts
where owner_profile_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa1';

select is(
  (select status::text from public.returns
   where id = '55555555-5555-5555-5555-555555555501'),
  'initiated',
  'a valid return starts in the initiated state'
);

select throws_ok(
  $$
  insert into public.returns (account_id, item_id, purchase_id)
  select id,
         '11111111-1111-1111-1111-111111111103',
         (select id from lifecycle_ids where key = 'unpriced_purchase')
  from public.accounts
  where owner_profile_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa1'
  $$,
  '23503', 'return purchase does not belong to the item',
  'a return cannot pair a purchase with the wrong item'
);

insert into public.returns (id, account_id, item_id)
select
  '55555555-5555-5555-5555-555555555502',
  id,
  '11111111-1111-1111-1111-111111111103'
from public.accounts
where owner_profile_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa1';

update public.returns
set status = 'denied'
where id = '55555555-5555-5555-5555-555555555502';

select ok(
  (select resolved_at is not null from public.returns
   where id = '55555555-5555-5555-5555-555555555502'),
  'denying a return records its resolution time'
);

select throws_ok(
  $$
  update public.returns
  set status = 'shipped'
  where id = '55555555-5555-5555-5555-555555555502'
  $$,
  '23514', 'invalid return status transition',
  'a denied return cannot be reopened through a direct update'
);

select public.refund_return_with_money_event(
  (select id from public.accounts
   where owner_profile_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa1'),
  '55555555-5555-5555-5555-555555555501',
  '11111111-1111-1111-1111-111111111102',
  700
);

select is(
  (select count(*) from public.money_events
   where source_type = 'return'
     and source_id = '55555555-5555-5555-5555-555555555501'
     and kind = 'refund'),
  1::bigint,
  'refunding a return creates one sourced refund event'
);

select is(
  (select amount_cents from public.money_events
   where source_id = '55555555-5555-5555-5555-555555555501'),
  700::bigint,
  'the refund event uses the exact refund amount'
);

select is(
  (select status::text from public.items
   where id = '11111111-1111-1111-1111-111111111102'),
  'returned',
  'refunding a return marks the linked item returned'
);

select public.refund_return_with_money_event(
  (select id from public.accounts
   where owner_profile_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa1'),
  '55555555-5555-5555-5555-555555555501',
  '11111111-1111-1111-1111-111111111102',
  700
);

select throws_ok(
  $$
  select public.refund_return_with_money_event(
    (select id from public.accounts
     where owner_profile_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa1'),
    '55555555-5555-5555-5555-555555555501',
    '11111111-1111-1111-1111-111111111102',
    999
  )
  $$,
  '23514', 'return is already refunded',
  'a settled refund cannot be rewritten with a different amount'
);

select is(
  (select refund_amount_cents from public.returns
   where id = '55555555-5555-5555-5555-555555555501'),
  700::bigint,
  'a repeated refund request cannot rewrite the settled amount'
);

select is(
  (select count(*) from public.money_events
   where source_id = '55555555-5555-5555-5555-555555555501'),
  1::bigint,
  'a repeated refund request cannot duplicate the ledger event'
);

select throws_ok(
  $$
  update public.returns
  set status = 'received'
  where id = '55555555-5555-5555-5555-555555555501'
  $$,
  '23514', 'invalid return status transition',
  'a refunded return is final'
);

select throws_ok(
  $$
  insert into public.money_events (
    account_id, item_id, kind, amount_cents, source_type, source_id
  )
  select account_id, item_id, 'refund', 700, 'return', id
  from public.returns
  where id = '55555555-5555-5555-5555-555555555501'
  $$,
  '23505', null,
  'the ledger rejects a duplicate source and kind'
);

-- Cross-account attempts remain blocked by the same-account trigger layer.
select pg_temp.authenticate_as('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa2');

insert into public.items (id, account_id, name)
select '11111111-1111-1111-1111-111111111104', id, 'Other account item'
from public.accounts
where owner_profile_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa2';

select pg_temp.authenticate_as('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa1');

select throws_ok(
  $$
  select public.create_purchase_with_money_event(
    (select id from public.accounts
     where owner_profile_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa1'),
    '11111111-1111-1111-1111-111111111104',
    null, null, 100, null, null
  )
  $$,
  '23503', null,
  'a purchase cannot reference another account item'
);

select ok(
  not exists (
    select 1
    from pg_proc as proc
    join pg_namespace as namespace on namespace.oid = proc.pronamespace
    where namespace.nspname = 'private'
      and proc.proname in (
        'guard_purchase_lifecycle', 'guard_listing_lifecycle',
        'guard_sale_lifecycle', 'guard_return_lifecycle'
      )
      and proc.prosecdef
  ),
  'all lifecycle trigger functions run with invoker rights'
);

select ok(
  not exists (
    select 1
    from pg_proc as proc
    join pg_namespace as namespace on namespace.oid = proc.pronamespace
    where namespace.nspname = 'private'
      and proc.proname in (
        'guard_purchase_lifecycle', 'guard_listing_lifecycle',
        'guard_sale_lifecycle', 'guard_return_lifecycle'
      )
      and has_function_privilege('authenticated', proc.oid, 'execute')
  ),
  'authenticated cannot call private lifecycle trigger functions as RPCs'
);

select ok(
  not exists (
    select 1
    from pg_proc as proc
    join pg_namespace as namespace on namespace.oid = proc.pronamespace
    where namespace.nspname = 'private'
      and proc.proname in (
        'guard_purchase_lifecycle', 'guard_listing_lifecycle',
        'guard_sale_lifecycle', 'guard_return_lifecycle'
      )
      and has_function_privilege('anon', proc.oid, 'execute')
  ),
  'anonymous callers cannot call private lifecycle trigger functions'
);

select ok(
  not exists (
    select 1
    from pg_proc as proc
    join pg_namespace as namespace on namespace.oid = proc.pronamespace
    where namespace.nspname = 'public'
      and proc.proname in (
        'create_purchase_with_money_event', 'create_listing_and_mark_item',
        'record_item_sale', 'refund_return_with_money_event'
      )
      and proc.prosecdef
  ),
  'all public lifecycle APIs run with invoker rights'
);

select ok(
  not exists (
    select 1
    from pg_proc as proc
    join pg_namespace as namespace on namespace.oid = proc.pronamespace
    where namespace.nspname = 'public'
      and proc.proname in (
        'create_purchase_with_money_event', 'create_listing_and_mark_item',
        'record_item_sale', 'refund_return_with_money_event'
      )
      and has_function_privilege('anon', proc.oid, 'execute')
  ),
  'anonymous callers cannot execute lifecycle APIs'
);

select is(
  (
    select count(*)
    from pg_proc as proc
    join pg_namespace as namespace on namespace.oid = proc.pronamespace
    where namespace.nspname = 'public'
      and proc.proname in (
        'create_purchase_with_money_event', 'create_listing_and_mark_item',
        'record_item_sale', 'refund_return_with_money_event'
      )
      and has_function_privilege('authenticated', proc.oid, 'execute')
  ),
  4::bigint,
  'authenticated can execute all four lifecycle APIs'
);

select is(
  has_table_privilege('authenticated', 'public.sales', 'update'),
  false,
  'authenticated clients cannot rewrite settled sale records'
);

select throws_ok(
  $$
  update public.sales
  set fees_cents = 50, net_amount_cents = 950
  where id = (select id from lifecycle_ids where key = 'sale')
  $$,
  '42501', null,
  'a direct settled-sale correction is rejected'
);

select * from finish();

rollback;
