-- pgTAP regression tests for Money integrity
-- (supabase/migrations/20260822163000_money_integrity.sql). Run with:
--   supabase test db --local supabase/tests/database
--
-- Runs inside one transaction rolled back at the end (same pattern as
-- 002_quote_rpc.sql / 003_today_automation.sql).

create extension if not exists pgtap;

begin;

select plan(10);

-- ---------------------------------------------------------------------------
-- Fixtures: two auth users (frank = the account under test, grace =
-- unrelated, for the isolation/authorization cases).
-- ---------------------------------------------------------------------------

do $$
declare
  v_instance_id uuid := '00000000-0000-0000-0000-000000000000';
begin
  insert into auth.users (
    instance_id, id, aud, role, email, encrypted_password,
    email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
    created_at, updated_at
  ) values
    (v_instance_id, '66666666-6666-6666-6666-666666666666', 'authenticated', 'authenticated',
     'frank@test.local', crypt('password123', gen_salt('bf')), now(), '{}', '{}', now(), now()),
    (v_instance_id, '77777777-7777-7777-7777-777777777777', 'authenticated', 'authenticated',
     'grace@test.local', crypt('password123', gen_salt('bf')), now(), '{}', '{}', now(), now());
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

select pg_temp.authenticate_as('66666666-6666-6666-6666-666666666666');

-- ---------------------------------------------------------------------------
-- Zero/negative: the schema itself rejects a non-positive amount, not just
-- client-side validation.
-- ---------------------------------------------------------------------------

select throws_ok(
  $$
  insert into public.money_events (account_id, kind, amount_cents)
  select id, 'earn', 0 from public.accounts
  where owner_profile_id = '66666666-6666-6666-6666-666666666666'
  $$,
  '23514', null,
  'a zero-cent event is rejected by the schema'
);

select throws_ok(
  $$
  insert into public.money_events (account_id, kind, amount_cents)
  select id, 'earn', -500 from public.accounts
  where owner_profile_id = '66666666-6666-6666-6666-666666666666'
  $$,
  '23514', null,
  'a negative-cent event is rejected by the schema'
);

-- ---------------------------------------------------------------------------
-- Partial refund: a $100 sale followed by a $30 partial refund of it --
-- both count in their own bucket, and NET reflects both as value LOOP
-- delivered (a refund protects the user, so it adds to NET, same as the
-- existing web/mobile sign convention).
-- ---------------------------------------------------------------------------

insert into public.money_events (account_id, kind, amount_cents, description)
select id, 'earn', 10000, 'Sale' from public.accounts
where owner_profile_id = '66666666-6666-6666-6666-666666666666';

insert into public.money_events (account_id, kind, amount_cents, description)
select id, 'refund', 3000, 'Partial refund' from public.accounts
where owner_profile_id = '66666666-6666-6666-6666-666666666666';

select is(
  (select made_cents from public.account_money_totals(
    (select id from public.accounts where owner_profile_id = '66666666-6666-6666-6666-666666666666')
  )),
  10000::bigint,
  'MADE reflects the sale'
);

select is(
  (select protected_cents from public.account_money_totals(
    (select id from public.accounts where owner_profile_id = '66666666-6666-6666-6666-666666666666')
  )),
  3000::bigint,
  'PROTECTED reflects the partial refund'
);

select is(
  (select net_cents from public.account_money_totals(
    (select id from public.accounts where owner_profile_id = '66666666-6666-6666-6666-666666666666')
  )),
  13000::bigint,
  'NET is MADE + PROTECTED for a sale plus its partial refund'
);

-- ---------------------------------------------------------------------------
-- Duplicate event: this is an append-only ledger, not a deduplicated fact
-- store -- two identical entries (e.g. two separate $5 fees) must both
-- count, not collapse into one.
-- ---------------------------------------------------------------------------

insert into public.money_events (account_id, kind, amount_cents, description)
select id, 'fee', 500, 'Listing fee' from public.accounts
where owner_profile_id = '66666666-6666-6666-6666-666666666666';

insert into public.money_events (account_id, kind, amount_cents, description)
select id, 'fee', 500, 'Listing fee' from public.accounts
where owner_profile_id = '66666666-6666-6666-6666-666666666666';

select is(
  (select fees_cents from public.account_money_totals(
    (select id from public.accounts where owner_profile_id = '66666666-6666-6666-6666-666666666666')
  )),
  1000::bigint,
  'two identical fee events both count -- duplicates are not collapsed'
);

-- ---------------------------------------------------------------------------
-- Currency precision: cent amounts that would drift under floating-point
-- arithmetic (e.g. 333 + 333 + 334) must sum exactly under bigint math.
-- ---------------------------------------------------------------------------

insert into public.money_events (account_id, kind, amount_cents, description)
select id, 'spend', v.cents, 'Precision check'
from public.accounts, (values (333), (333), (334)) as v(cents)
where owner_profile_id = '66666666-6666-6666-6666-666666666666';

select is(
  (select spent_cents from public.account_money_totals(
    (select id from public.accounts where owner_profile_id = '66666666-6666-6666-6666-666666666666')
  )),
  1000::bigint,
  'three odd cent amounts (333+333+334) sum to exactly 1000 with no drift'
);

-- ---------------------------------------------------------------------------
-- Account isolation: an unrelated account's events never leak into these
-- totals, and an unrelated user cannot query this account's totals at all.
-- ---------------------------------------------------------------------------

select pg_temp.authenticate_as('77777777-7777-7777-7777-777777777777');

insert into public.money_events (account_id, kind, amount_cents, description)
select id, 'earn', 999999, 'Grace''s own sale, must never appear in Frank''s totals'
from public.accounts
where owner_profile_id = '77777777-7777-7777-7777-777777777777';

select throws_ok(
  $$ select public.account_money_totals(
    (select id from public.accounts where owner_profile_id = '66666666-6666-6666-6666-666666666666')
  ) $$,
  'P0001',
  'not authorized for this account',
  'grace cannot pull totals for frank''s account'
);

select pg_temp.authenticate_as('66666666-6666-6666-6666-666666666666');

select is(
  (select made_cents from public.account_money_totals(
    (select id from public.accounts where owner_profile_id = '66666666-6666-6666-6666-666666666666')
  )),
  10000::bigint,
  'frank''s MADE total is unaffected by grace''s events -- no cross-account leakage'
);

select throws_ok(
  $$ select public.account_money_totals(
    (select id from public.accounts where owner_profile_id = '77777777-7777-7777-7777-777777777777')
  ) $$,
  'P0001',
  'not authorized for this account',
  'frank cannot pull totals for grace''s account'
);

select * from finish();

rollback;
