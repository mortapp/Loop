-- Harden PROTECT/RECOVER money lifecycle writes without breaking older
-- installed clients. Validation triggers protect direct writes; updated
-- clients use the atomic invoker-rights RPCs below so dependent rows commit
-- or roll back together. No side-effect trigger is used because older clients
-- still perform those follow-up writes themselves.

-- ---------------------------------------------------------------------------
-- Monetary and state invariants. Hosted preflight confirmed these tables are
-- empty, so no legacy rows need rewriting before validation.
-- ---------------------------------------------------------------------------

alter table public.items
  add constraint items_name_not_blank
    check (char_length(btrim(name)) between 1 and 200),
  add constraint items_purchase_price_valid
    check (
      purchase_price_cents is null
      or purchase_price_cents between 0 and 100000000000
    );

alter table public.purchases
  add constraint purchases_price_valid
    check (price_cents is null or price_cents between 0 and 100000000000),
  add constraint purchases_vendor_name_length
    check (vendor_name is null or char_length(btrim(vendor_name)) between 1 and 200),
  add constraint purchases_date_order
    check (
      purchase_date is null
      or (
        (return_window_expires_at is null or return_window_expires_at >= purchase_date)
        and (warranty_expires_at is null or warranty_expires_at >= purchase_date)
      )
    );

alter table public.valuations
  add constraint valuations_amount_valid
    check (estimated_value_cents between 1 and 100000000000);

alter table public.listings
  add constraint listings_marketplace_not_blank
    check (char_length(btrim(marketplace)) between 1 and 120),
  add constraint listings_price_valid
    check (list_price_cents is null or list_price_cents between 0 and 100000000000);

alter table public.sales
  add constraint sales_amounts_valid
    check (
      sale_price_cents between 1 and 100000000000
      and fees_cents between 0 and sale_price_cents
      and net_amount_cents = sale_price_cents - fees_cents
    );

alter table public.returns
  add constraint returns_refund_state_valid
    check (
      (
        status = 'refunded'
        and refund_amount_cents between 1 and 100000000000
        and resolved_at is not null
      )
      or (
        status <> 'refunded'
        and refund_amount_cents is null
      )
    ),
  add constraint returns_denied_is_resolved
    check (status <> 'denied' or resolved_at is not null);

create unique index sales_one_per_item_idx
  on public.sales (item_id);

create unique index money_events_unique_source_kind_idx
  on public.money_events (account_id, source_type, source_id, kind)
  where source_id is not null;

-- ---------------------------------------------------------------------------
-- Backward-compatible direct-write guards. They have no side effects, run as
-- the caller, and keep the existing RLS boundary in force.
-- ---------------------------------------------------------------------------

create or replace function private.guard_purchase_lifecycle()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
  if new.account_id is distinct from old.account_id
    or new.item_id is distinct from old.item_id
    or new.price_cents is distinct from old.price_cents then
    raise exception using
      errcode = '23514',
      message = 'purchase financial identity is immutable';
  end if;
  return new;
end;
$$;

create trigger purchases_guard_lifecycle
  before update on public.purchases
  for each row execute function private.guard_purchase_lifecycle();

create or replace function private.guard_listing_lifecycle()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_item_status text;
begin
  if tg_op = 'UPDATE' then
    if new.account_id is distinct from old.account_id
      or new.item_id is distinct from old.item_id then
      raise exception using
        errcode = '23514',
        message = 'listing ownership is immutable';
    end if;

    if old.status in ('sold', 'removed') and new.status is distinct from old.status then
      raise exception using
        errcode = '23514',
        message = 'closed listing status is final';
    end if;
    return new;
  end if;

  if new.status not in ('draft', 'active') then
    raise exception using
      errcode = '23514',
      message = 'new listings must be draft or active';
  end if;

  select item.status::text
    into v_item_status
    from public.items as item
   where item.id = new.item_id
     and item.account_id = new.account_id
   for update;

  if v_item_status is null then
    raise exception using
      errcode = '23503',
      message = 'listing item is unavailable';
  end if;

  if v_item_status not in ('owned', 'listed') then
    raise exception using
      errcode = '23514',
      message = 'item cannot be listed in its current state';
  end if;

  return new;
end;
$$;

create trigger listings_guard_lifecycle
  before insert or update on public.listings
  for each row execute function private.guard_listing_lifecycle();

create or replace function private.guard_sale_lifecycle()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_item_status text;
  v_listing_status text;
begin
  if tg_op = 'UPDATE' then
    if row(
      new.account_id,
      new.item_id,
      new.listing_id,
      new.sale_price_cents,
      new.fees_cents,
      new.net_amount_cents
    ) is distinct from row(
      old.account_id,
      old.item_id,
      old.listing_id,
      old.sale_price_cents,
      old.fees_cents,
      old.net_amount_cents
    ) then
      raise exception using
        errcode = '23514',
        message = 'sale financial record is immutable';
    end if;
    return new;
  end if;

  select item.status::text
    into v_item_status
    from public.items as item
   where item.id = new.item_id
     and item.account_id = new.account_id
   for update;

  if v_item_status is null then
    raise exception using
      errcode = '23503',
      message = 'sale item is unavailable';
  end if;

  if v_item_status not in ('owned', 'listed') then
    raise exception using
      errcode = '23514',
      message = 'item cannot be sold in its current state';
  end if;

  if new.listing_id is not null then
    select listing.status::text
      into v_listing_status
      from public.listings as listing
     where listing.id = new.listing_id
       and listing.account_id = new.account_id
       and listing.item_id = new.item_id
     for update;

    if v_listing_status is null then
      raise exception using
        errcode = '23503',
        message = 'sale listing does not belong to the item';
    end if;

    if v_listing_status not in ('draft', 'active') then
      raise exception using
        errcode = '23514',
        message = 'listing cannot be sold in its current state';
    end if;
  end if;

  return new;
end;
$$;

create trigger sales_guard_lifecycle
  before insert or update on public.sales
  for each row execute function private.guard_sale_lifecycle();

create or replace function private.guard_return_lifecycle()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_purchase_item_id uuid;
begin
  if tg_op = 'INSERT' then
    if new.status <> 'initiated' then
      raise exception using
        errcode = '23514',
        message = 'new returns must start as initiated';
    end if;
  else
    if row(new.account_id, new.item_id, new.purchase_id)
      is distinct from row(old.account_id, old.item_id, old.purchase_id) then
      raise exception using
        errcode = '23514',
        message = 'return ownership is immutable';
    end if;

    if old.status = new.status then
      if old.status = 'refunded' then
        new.refund_amount_cents := old.refund_amount_cents;
        new.resolved_at := old.resolved_at;
      elsif old.status = 'denied' then
        new.resolved_at := old.resolved_at;
      end if;
    elsif not (
      (old.status = 'initiated' and new.status in ('shipped', 'received', 'refunded', 'denied'))
      or (old.status = 'shipped' and new.status in ('received', 'refunded', 'denied'))
      or (old.status = 'received' and new.status in ('refunded', 'denied'))
    ) then
      raise exception using
        errcode = '23514',
        message = 'invalid return status transition';
    end if;
  end if;

  if new.purchase_id is not null then
    select purchase.item_id
      into v_purchase_item_id
      from public.purchases as purchase
     where purchase.id = new.purchase_id
       and purchase.account_id = new.account_id;

    if v_purchase_item_id is null or v_purchase_item_id <> new.item_id then
      raise exception using
        errcode = '23503',
        message = 'return purchase does not belong to the item';
    end if;
  end if;

  if new.status = 'refunded' then
    if new.refund_amount_cents is null
      or new.refund_amount_cents < 1
      or new.refund_amount_cents > 100000000000
      or new.resolved_at is null then
      raise exception using
        errcode = '23514',
        message = 'refunded returns require a valid amount and resolution time';
    end if;
  else
    new.refund_amount_cents := null;
    if new.status = 'denied' and new.resolved_at is null then
      new.resolved_at := now();
    elsif new.status <> 'denied' then
      new.resolved_at := null;
    end if;
  end if;

  return new;
end;
$$;

create trigger returns_guard_lifecycle
  before insert or update on public.returns
  for each row execute function private.guard_return_lifecycle();

revoke execute on function private.guard_purchase_lifecycle() from public, anon, authenticated;
revoke execute on function private.guard_listing_lifecycle() from public, anon, authenticated;
revoke execute on function private.guard_sale_lifecycle() from public, anon, authenticated;
revoke execute on function private.guard_return_lifecycle() from public, anon, authenticated;

-- Direct sale edits would diverge from the append-only ledger. A future
-- correction flow must write compensating ledger entries atomically.
drop policy "sales_update" on public.sales;
revoke update on public.sales from authenticated;

-- ---------------------------------------------------------------------------
-- Atomic APIs used by both current clients after this migration.
-- SECURITY INVOKER is explicit: all table RLS and grants still apply.
-- ---------------------------------------------------------------------------

create or replace function public.create_purchase_with_money_event(
  p_account_id uuid,
  p_item_id uuid,
  p_vendor_name text,
  p_purchase_date date,
  p_price_cents bigint,
  p_return_window_expires_at date,
  p_warranty_expires_at date
)
returns uuid
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_purchase_id uuid;
  v_vendor_name text := nullif(btrim(p_vendor_name), '');
begin
  if auth.uid() is null or not public.has_account_access(p_account_id) then
    raise exception using errcode = '42501', message = 'not authorized for this account';
  end if;

  if p_item_id is not null and not exists (
    select 1 from public.items
    where id = p_item_id and account_id = p_account_id
  ) then
    raise exception using errcode = '23503', message = 'purchase item is unavailable';
  end if;

  insert into public.purchases (
    account_id, item_id, vendor_name, purchase_date, price_cents,
    return_window_expires_at, warranty_expires_at, created_by
  ) values (
    p_account_id, p_item_id, v_vendor_name, p_purchase_date, p_price_cents,
    p_return_window_expires_at, p_warranty_expires_at, auth.uid()
  ) returning id into v_purchase_id;

  if p_price_cents is not null and p_price_cents > 0 then
    insert into public.money_events (
      account_id, item_id, kind, amount_cents,
      source_type, source_id, description, created_by
    ) values (
      p_account_id, p_item_id, 'spend', p_price_cents,
      'purchase', v_purchase_id,
      case when v_vendor_name is null then 'Purchase' else 'Purchase from ' || v_vendor_name end,
      auth.uid()
    );
  end if;

  return v_purchase_id;
end;
$$;

create or replace function public.create_listing_and_mark_item(
  p_account_id uuid,
  p_item_id uuid,
  p_marketplace text,
  p_list_price_cents bigint
)
returns uuid
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_listing_id uuid;
begin
  if auth.uid() is null or not public.has_account_access(p_account_id) then
    raise exception using errcode = '42501', message = 'not authorized for this account';
  end if;

  insert into public.listings (
    account_id, item_id, marketplace, status,
    list_price_cents, published_at, created_by
  ) values (
    p_account_id, p_item_id, btrim(p_marketplace), 'active',
    p_list_price_cents, now(), auth.uid()
  ) returning id into v_listing_id;

  update public.items
     set status = 'listed'
   where id = p_item_id and account_id = p_account_id;

  if not found then
    raise exception using errcode = '23503', message = 'listing item is unavailable';
  end if;

  return v_listing_id;
end;
$$;

create or replace function public.record_item_sale(
  p_account_id uuid,
  p_item_id uuid,
  p_listing_id uuid,
  p_sale_price_cents bigint,
  p_fees_cents bigint
)
returns uuid
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_sale_id uuid;
begin
  if auth.uid() is null or not public.has_account_access(p_account_id) then
    raise exception using errcode = '42501', message = 'not authorized for this account';
  end if;

  insert into public.sales (
    account_id, item_id, listing_id,
    sale_price_cents, fees_cents, net_amount_cents, created_by
  ) values (
    p_account_id, p_item_id, p_listing_id,
    p_sale_price_cents, p_fees_cents,
    p_sale_price_cents - p_fees_cents, auth.uid()
  ) returning id into v_sale_id;

  update public.items
     set status = 'sold'
   where id = p_item_id and account_id = p_account_id;

  if not found then
    raise exception using errcode = '23503', message = 'sale item is unavailable';
  end if;

  if p_listing_id is not null then
    update public.listings
       set status = 'sold'
     where id = p_listing_id
       and account_id = p_account_id
       and item_id = p_item_id;

    if not found then
      raise exception using errcode = '23503', message = 'sale listing is unavailable';
    end if;
  end if;

  insert into public.money_events (
    account_id, item_id, kind, amount_cents,
    source_type, source_id, description, created_by
  ) values (
    p_account_id, p_item_id, 'recovered', p_sale_price_cents,
    'sale', v_sale_id, 'Item sold via RECOVER', auth.uid()
  );

  if p_fees_cents > 0 then
    insert into public.money_events (
      account_id, item_id, kind, amount_cents,
      source_type, source_id, description, created_by
    ) values (
      p_account_id, p_item_id, 'fee', p_fees_cents,
      'sale', v_sale_id, 'Sale fees', auth.uid()
    );
  end if;

  return v_sale_id;
end;
$$;

create or replace function public.refund_return_with_money_event(
  p_account_id uuid,
  p_return_id uuid,
  p_item_id uuid,
  p_refund_amount_cents bigint
)
returns void
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_status text;
  v_existing_amount bigint;
begin
  if auth.uid() is null or not public.has_account_access(p_account_id) then
    raise exception using errcode = '42501', message = 'not authorized for this account';
  end if;

  select status::text, refund_amount_cents
    into v_status, v_existing_amount
    from public.returns
   where id = p_return_id
     and account_id = p_account_id
     and item_id = p_item_id
   for update;

  if v_status is null then
    raise exception using errcode = '23503', message = 'return is unavailable';
  end if;

  if v_status = 'refunded' then
    if v_existing_amount = p_refund_amount_cents then
      return;
    end if;
    raise exception using errcode = '23514', message = 'return is already refunded';
  end if;

  if v_status = 'denied' then
    raise exception using errcode = '23514', message = 'denied return cannot be refunded';
  end if;

  update public.returns
     set status = 'refunded',
         refund_amount_cents = p_refund_amount_cents,
         resolved_at = now()
   where id = p_return_id;

  update public.items
     set status = 'returned'
   where id = p_item_id and account_id = p_account_id;

  if not found then
    raise exception using errcode = '23503', message = 'return item is unavailable';
  end if;

  insert into public.money_events (
    account_id, item_id, kind, amount_cents,
    source_type, source_id, description, created_by
  ) values (
    p_account_id, p_item_id, 'refund', p_refund_amount_cents,
    'return', p_return_id, 'Return refunded', auth.uid()
  );
end;
$$;

revoke execute on function public.create_purchase_with_money_event(uuid, uuid, text, date, bigint, date, date)
  from public, anon;
grant execute on function public.create_purchase_with_money_event(uuid, uuid, text, date, bigint, date, date)
  to authenticated;

revoke execute on function public.create_listing_and_mark_item(uuid, uuid, text, bigint)
  from public, anon;
grant execute on function public.create_listing_and_mark_item(uuid, uuid, text, bigint)
  to authenticated;

revoke execute on function public.record_item_sale(uuid, uuid, uuid, bigint, bigint)
  from public, anon;
grant execute on function public.record_item_sale(uuid, uuid, uuid, bigint, bigint)
  to authenticated;

revoke execute on function public.refund_return_with_money_event(uuid, uuid, uuid, bigint)
  from public, anon;
grant execute on function public.refund_return_with_money_event(uuid, uuid, uuid, bigint)
  to authenticated;
