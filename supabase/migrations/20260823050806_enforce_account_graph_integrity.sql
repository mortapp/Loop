-- Cross-account integrity and actor-authenticity hardening.
--
-- RLS already limits each top-level row by account_id. It does not, by
-- itself, prove that a nested UUID (item_id, contact_id, purchase_id, ...)
-- belongs to that same account. These trigger checks close that BOLA-shaped
-- integrity gap without changing any existing client payloads or RPC names.

create schema if not exists private;
revoke all on schema private from public, anon, authenticated;

create or replace function private.enforce_same_account_reference()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_reference_id uuid;
  v_account_id uuid;
  v_parent_account_id uuid;
begin
  if tg_nargs <> 2 then
    raise exception 'same-account trigger is misconfigured';
  end if;

  if not (tg_argv[1] = any (array[
    'contacts', 'documents', 'items', 'leads', 'listings',
    'opportunities', 'purchases'
  ])) then
    raise exception 'same-account trigger has an unsupported parent';
  end if;

  v_reference_id := nullif(pg_catalog.to_jsonb(new) ->> tg_argv[0], '')::uuid;
  if v_reference_id is null then
    return new;
  end if;

  v_account_id := (pg_catalog.to_jsonb(new) ->> 'account_id')::uuid;

  execute pg_catalog.format(
    'select parent.account_id from public.%I parent where parent.id = $1',
    tg_argv[1]
  )
  into v_parent_account_id
  using v_reference_id;

  if v_parent_account_id is distinct from v_account_id then
    raise exception using
      errcode = '23514',
      message = 'Related record must belong to the selected account.';
  end if;

  return new;
end;
$$;

create or replace function private.enforce_profile_account_reference()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_profile_id uuid;
  v_account_id uuid;
  v_has_access boolean;
begin
  if tg_nargs <> 1 or tg_argv[0] <> 'assigned_to' then
    raise exception 'profile-account trigger is misconfigured';
  end if;

  v_profile_id := nullif(pg_catalog.to_jsonb(new) ->> tg_argv[0], '')::uuid;
  if v_profile_id is null then
    return new;
  end if;

  v_account_id := (pg_catalog.to_jsonb(new) ->> 'account_id')::uuid;

  select exists (
    select 1
    from public.accounts account_row
    where account_row.id = v_account_id
      and (
        (
          account_row.type = 'personal'
          and account_row.owner_profile_id = v_profile_id
        )
        or (
          account_row.type = 'business'
          and exists (
            select 1
            from public.business_members membership
            where membership.business_id = account_row.business_id
              and membership.profile_id = v_profile_id
              and membership.status = 'active'
          )
        )
      )
  ) into v_has_access;

  if not coalesce(v_has_access, false) then
    raise exception using
      errcode = '23514',
      message = 'Assigned profile must have access to the selected account.';
  end if;

  return new;
end;
$$;

create or replace function private.stamp_authenticated_actor()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
begin
  if tg_nargs <> 1
    or not (tg_argv[0] = any (array[
      'actor_profile_id', 'created_by', 'invited_by'
    ])) then
    raise exception 'actor trigger is misconfigured';
  end if;

  if tg_op = 'INSERT' and v_user_id is not null then
    new := pg_catalog.jsonb_populate_record(
      new,
      pg_catalog.jsonb_build_object(tg_argv[0], v_user_id)
    );
  elsif tg_op = 'UPDATE' then
    new := pg_catalog.jsonb_populate_record(
      new,
      pg_catalog.jsonb_build_object(
        tg_argv[0],
        pg_catalog.to_jsonb(old) -> tg_argv[0]
      )
    );
  end if;

  return new;
end;
$$;

create or replace function private.sync_profile_email_from_auth()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.email is distinct from old.email and new.email is not null then
    update public.profiles
    set email = new.email
    where id = new.id;
  end if;

  return new;
end;
$$;

revoke all on function private.enforce_same_account_reference()
  from public, anon, authenticated;
revoke all on function private.enforce_profile_account_reference()
  from public, anon, authenticated;
revoke all on function private.stamp_authenticated_actor()
  from public, anon, authenticated;
revoke all on function private.sync_profile_email_from_auth()
  from public, anon, authenticated;

-- Nested domain references must stay inside the row's account.
create trigger documents_item_same_account
  before insert or update of account_id, item_id on public.documents
  for each row execute function private.enforce_same_account_reference('item_id', 'items');

create trigger money_events_item_same_account
  before insert or update of account_id, item_id on public.money_events
  for each row execute function private.enforce_same_account_reference('item_id', 'items');

create trigger leads_contact_same_account
  before insert or update of account_id, contact_id on public.leads
  for each row execute function private.enforce_same_account_reference('contact_id', 'contacts');

create trigger opportunities_contact_same_account
  before insert or update of account_id, contact_id on public.opportunities
  for each row execute function private.enforce_same_account_reference('contact_id', 'contacts');

create trigger opportunities_lead_same_account
  before insert or update of account_id, lead_id on public.opportunities
  for each row execute function private.enforce_same_account_reference('lead_id', 'leads');

create trigger quotes_contact_same_account
  before insert or update of account_id, contact_id on public.quotes
  for each row execute function private.enforce_same_account_reference('contact_id', 'contacts');

create trigger quotes_opportunity_same_account
  before insert or update of account_id, opportunity_id on public.quotes
  for each row execute function private.enforce_same_account_reference('opportunity_id', 'opportunities');

create trigger purchases_item_same_account
  before insert or update of account_id, item_id on public.purchases
  for each row execute function private.enforce_same_account_reference('item_id', 'items');

create trigger purchases_vendor_contact_same_account
  before insert or update of account_id, vendor_contact_id on public.purchases
  for each row execute function private.enforce_same_account_reference('vendor_contact_id', 'contacts');

create trigger purchases_receipt_document_same_account
  before insert or update of account_id, receipt_document_id on public.purchases
  for each row execute function private.enforce_same_account_reference('receipt_document_id', 'documents');

create trigger returns_item_same_account
  before insert or update of account_id, item_id on public.returns
  for each row execute function private.enforce_same_account_reference('item_id', 'items');

create trigger returns_purchase_same_account
  before insert or update of account_id, purchase_id on public.returns
  for each row execute function private.enforce_same_account_reference('purchase_id', 'purchases');

create trigger warranties_item_same_account
  before insert or update of account_id, item_id on public.warranties
  for each row execute function private.enforce_same_account_reference('item_id', 'items');

create trigger valuations_item_same_account
  before insert or update of account_id, item_id on public.valuations
  for each row execute function private.enforce_same_account_reference('item_id', 'items');

create trigger listings_item_same_account
  before insert or update of account_id, item_id on public.listings
  for each row execute function private.enforce_same_account_reference('item_id', 'items');

create trigger sales_item_same_account
  before insert or update of account_id, item_id on public.sales
  for each row execute function private.enforce_same_account_reference('item_id', 'items');

create trigger sales_listing_same_account
  before insert or update of account_id, listing_id on public.sales
  for each row execute function private.enforce_same_account_reference('listing_id', 'listings');

create trigger sales_buyer_contact_same_account
  before insert or update of account_id, buyer_contact_id on public.sales
  for each row execute function private.enforce_same_account_reference('buyer_contact_id', 'contacts');

create trigger actions_assignee_same_account
  before insert or update of account_id, assigned_to on public.actions
  for each row execute function private.enforce_profile_account_reference('assigned_to');

-- Authenticated clients cannot forge actor/audit identities. INSERT stamps
-- the current auth user, while UPDATE preserves the original actor.
create trigger businesses_stamp_created_by
  before insert or update of created_by on public.businesses
  for each row execute function private.stamp_authenticated_actor('created_by');
create trigger business_members_stamp_invited_by
  before insert or update of invited_by on public.business_members
  for each row execute function private.stamp_authenticated_actor('invited_by');
create trigger contacts_stamp_created_by
  before insert or update of created_by on public.contacts
  for each row execute function private.stamp_authenticated_actor('created_by');
create trigger items_stamp_created_by
  before insert or update of created_by on public.items
  for each row execute function private.stamp_authenticated_actor('created_by');
create trigger documents_stamp_created_by
  before insert or update of created_by on public.documents
  for each row execute function private.stamp_authenticated_actor('created_by');
create trigger money_events_stamp_created_by
  before insert on public.money_events
  for each row execute function private.stamp_authenticated_actor('created_by');
create trigger actions_stamp_created_by
  before insert or update of created_by on public.actions
  for each row execute function private.stamp_authenticated_actor('created_by');
create trigger events_stamp_actor
  before insert on public.events
  for each row execute function private.stamp_authenticated_actor('actor_profile_id');
create trigger leads_stamp_created_by
  before insert or update of created_by on public.leads
  for each row execute function private.stamp_authenticated_actor('created_by');
create trigger opportunities_stamp_created_by
  before insert or update of created_by on public.opportunities
  for each row execute function private.stamp_authenticated_actor('created_by');
create trigger quotes_stamp_created_by
  before insert or update of created_by on public.quotes
  for each row execute function private.stamp_authenticated_actor('created_by');
create trigger purchases_stamp_created_by
  before insert or update of created_by on public.purchases
  for each row execute function private.stamp_authenticated_actor('created_by');
create trigger returns_stamp_created_by
  before insert or update of created_by on public.returns
  for each row execute function private.stamp_authenticated_actor('created_by');
create trigger warranties_stamp_created_by
  before insert or update of created_by on public.warranties
  for each row execute function private.stamp_authenticated_actor('created_by');
create trigger valuations_stamp_created_by
  before insert on public.valuations
  for each row execute function private.stamp_authenticated_actor('created_by');
create trigger listings_stamp_created_by
  before insert or update of created_by on public.listings
  for each row execute function private.stamp_authenticated_actor('created_by');
create trigger sales_stamp_created_by
  before insert or update of created_by on public.sales
  for each row execute function private.stamp_authenticated_actor('created_by');

-- The profile email mirrors Supabase Auth and is not a client-editable
-- display field. Auth updates are synchronized by a protected trigger.
revoke update on public.profiles from authenticated;
grant update (display_name, avatar_url, default_mode, username)
  on public.profiles to authenticated;

create trigger sync_profile_email_after_auth_update
  after update of email on auth.users
  for each row execute function private.sync_profile_email_from_auth();

-- Trigger-only helpers and the platform RLS event trigger do not need a
-- public RPC surface. Trigger execution does not depend on these grants.
revoke execute on function public.set_updated_at() from public, anon, authenticated;
revoke execute on function public.close_related_today_actions() from public, anon, authenticated;
revoke execute on function public.rls_auto_enable() from public, anon, authenticated;
revoke execute on function public.current_profile_id() from public, anon, authenticated;
revoke execute on function public.create_quote_with_line_items(
  uuid, uuid, uuid, text, bigint, bigint, bigint, uuid, jsonb
) from public, anon;
grant execute on function public.create_quote_with_line_items(
  uuid, uuid, uuid, text, bigint, bigint, bigint, uuid, jsonb
) to authenticated;

-- Keep the conservative business-members policy split while avoiding a
-- per-row auth.uid() re-evaluation in the self SELECT/DELETE paths.
drop policy "business_members_select_self" on public.business_members;
drop policy "business_members_delete_self" on public.business_members;

create policy "business_members_select_self"
  on public.business_members for select
  to authenticated
  using (profile_id = (select auth.uid()));

create policy "business_members_delete_self"
  on public.business_members for delete
  to authenticated
  using (profile_id = (select auth.uid()));
