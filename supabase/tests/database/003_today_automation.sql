-- pgTAP regression tests for Today automation
-- (supabase/migrations/20260822164226_today_automation.sql). Run with:
--   supabase test db --local supabase/tests/database
--
-- Everything here runs inside one transaction that is rolled back at the
-- end (see 002_quote_rpc.sql for the same pattern), so this never persists
-- fixture data even if pointed at a shared database by mistake.

create extension if not exists pgtap;

begin;

select plan(12);

-- ---------------------------------------------------------------------------
-- Fixtures: two auth users (dave = the account owner under test, eve = an
-- unrelated user with no access to dave's account), a quote due for a
-- follow-up nudge, an expiring quote, a purchase with a closing return
-- window, and a warranty about to lapse.
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
    (v_instance_id, '44444444-4444-4444-4444-444444444444', 'authenticated', 'authenticated',
     'dave@test.local', crypt('password123', gen_salt('bf')), now(), '{}', '{}', now(), now()),
    (v_instance_id, '55555555-5555-5555-5555-555555555555', 'authenticated', 'authenticated',
     'eve@test.local', crypt('password123', gen_salt('bf')), now(), '{}', '{}', now(), now());
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

select pg_temp.authenticate_as('44444444-4444-4444-4444-444444444444');

-- This block creates historical fixture states that ordinary clients cannot
-- manufacture directly (custom sent_at/valid_until timestamps).
reset role;

do $$
declare
  v_account_id uuid;
  v_item_id uuid;
  v_purchase_id uuid;
begin
  select id into v_account_id from public.accounts
  where owner_profile_id = '44444444-4444-4444-4444-444444444444';

  insert into public.items (account_id, name, status)
  values (v_account_id, 'Automation Test Widget', 'owned')
  returning id into v_item_id;

  -- Eligible: sent 4 days ago, no decision -> quote_follow_up.
  -- Also expiring tomorrow -> quote_expiring. Same quote triggers both.
  insert into public.quotes (account_id, quote_number, status, sent_at, valid_until)
  values (v_account_id, 'Q-AUTOMATION-DUE', 'sent', now() - interval '4 days', current_date + 1);

  -- Ineligible: sent moments ago, not due for a nudge yet.
  insert into public.quotes (account_id, quote_number, status, sent_at, valid_until)
  values (v_account_id, 'Q-AUTOMATION-FRESH', 'sent', now(), current_date + 30);

  -- Eligible: return window closes in 2 days, item still owned, no return yet.
  insert into public.purchases (account_id, item_id, return_window_expires_at)
  values (v_account_id, v_item_id, current_date + 2)
  returning id into v_purchase_id;

  -- Eligible: warranty lapses in 10 days, no claim filed.
  insert into public.warranties (account_id, item_id, expires_at)
  values (v_account_id, v_item_id, current_date + 10);
end $$;

select pg_temp.authenticate_as('44444444-4444-4444-4444-444444444444');

-- ---------------------------------------------------------------------------
-- Generation: exactly the 4 eligible rows, nothing for the fresh quote.
-- ---------------------------------------------------------------------------

select lives_ok(
  $$ select public.generate_today_actions(
    (select id from public.accounts where owner_profile_id = '44444444-4444-4444-4444-444444444444')
  ) $$,
  'generate_today_actions succeeds for an account the caller owns'
);

select is(
  (select count(*)::int from public.actions a
   join public.accounts acc on acc.id = a.account_id
   where acc.owner_profile_id = '44444444-4444-4444-4444-444444444444'),
  4,
  'exactly 4 actions were generated: quote_follow_up, quote_expiring, return_window_expiring, warranty_expiring'
);

select is(
  (select count(*)::int from public.actions a
   join public.accounts acc on acc.id = a.account_id
   where acc.owner_profile_id = '44444444-4444-4444-4444-444444444444'
     and a.related_type = 'quote'
     and a.related_id = (select id from public.quotes where quote_number = 'Q-AUTOMATION-FRESH')),
  0,
  'the not-yet-due quote generated no actions'
);

select is(
  (select type from public.actions a
   join public.quotes q on q.id = a.related_id and a.related_type = 'quote'
   where q.quote_number = 'Q-AUTOMATION-DUE' and a.type = 'quote_follow_up'),
  'quote_follow_up',
  'the overdue quote generated a quote_follow_up action'
);

select is(
  (select type from public.actions a
   join public.quotes q on q.id = a.related_id and a.related_type = 'quote'
   where q.quote_number = 'Q-AUTOMATION-DUE' and a.type = 'quote_expiring'),
  'quote_expiring',
  'the soon-to-expire quote generated a quote_expiring action'
);

-- ---------------------------------------------------------------------------
-- Idempotency: calling again inserts nothing new (the partial unique index
-- + on conflict do nothing is what makes this atomic, not an app-side check).
-- ---------------------------------------------------------------------------

select is(
  (select count(*)::int from public.generate_today_actions(
    (select id from public.accounts where owner_profile_id = '44444444-4444-4444-4444-444444444444')
  )),
  0,
  'a second call generates zero additional rows for the same still-open state'
);

select is(
  (select count(*)::int from public.actions a
   join public.accounts acc on acc.id = a.account_id
   where acc.owner_profile_id = '44444444-4444-4444-4444-444444444444'),
  4,
  'the total action count is unchanged after the second call'
);

-- ---------------------------------------------------------------------------
-- Authorization: an unrelated user cannot generate actions for dave's account.
-- ---------------------------------------------------------------------------

select pg_temp.authenticate_as('55555555-5555-5555-5555-555555555555');

select throws_ok(
  $$ select public.generate_today_actions(
    (select id from public.accounts where owner_profile_id = '44444444-4444-4444-4444-444444444444')
  ) $$,
  'P0001',
  'not authorized for this account',
  'a user with no access to the account is rejected'
);

select pg_temp.authenticate_as('44444444-4444-4444-4444-444444444444');

-- ---------------------------------------------------------------------------
-- Lifecycle transitions: resolving the underlying thing auto-closes the
-- action Today generated for it.
-- ---------------------------------------------------------------------------

update public.quotes set status = 'accepted' where quote_number = 'Q-AUTOMATION-DUE';

select is(
  (select count(*)::int from public.actions a
   join public.quotes q on q.id = a.related_id and a.related_type = 'quote'
   where q.quote_number = 'Q-AUTOMATION-DUE' and a.status = 'done'),
  2,
  'accepting the quote auto-closes both of its generated actions'
);

insert into public.returns (account_id, item_id, purchase_id)
select account_id, item_id, id from public.purchases
where account_id = (select id from public.accounts where owner_profile_id = '44444444-4444-4444-4444-444444444444');

select is(
  (select status from public.actions where type = 'return_window_expiring'
   and related_id = (select id from public.purchases
     where account_id = (select id from public.accounts where owner_profile_id = '44444444-4444-4444-4444-444444444444')))::text,
  'done',
  'starting a return auto-closes the return_window_expiring action'
);

update public.warranties set claim_status = 'filed'
where account_id = (select id from public.accounts where owner_profile_id = '44444444-4444-4444-4444-444444444444');

select is(
  (select status from public.actions where type = 'warranty_expiring'
   and related_id = (select id from public.warranties
     where account_id = (select id from public.accounts where owner_profile_id = '44444444-4444-4444-4444-444444444444')))::text,
  'done',
  'filing a warranty claim auto-closes the warranty_expiring action'
);

select is(
  (select count(*)::int from public.generate_today_actions(
    (select id from public.accounts where owner_profile_id = '44444444-4444-4444-4444-444444444444')
  )),
  0,
  'resolved items do not regenerate -- the dedup key still holds after the row was marked done'
);

select * from finish();

rollback;
