-- Quote status changes and their Money side effects are one server-owned
-- transaction. The caller supplies only a quote id and enum value; account,
-- amount, source identity, and actor are resolved and authorized in Postgres.

create or replace function public.set_quote_status_with_money_event(
  p_quote_id uuid,
  p_status public.quote_status
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_account_id uuid;
  v_previous_status public.quote_status;
  v_total_cents bigint;
  v_quote_number text;
begin
  if auth.uid() is null then
    raise exception using errcode = '42501', message = 'authentication required';
  end if;

  select quote.account_id, quote.status, quote.total_cents, quote.quote_number
    into v_account_id, v_previous_status, v_total_cents, v_quote_number
    from public.quotes as quote
   where quote.id = p_quote_id
   for update;

  if not found or not public.has_account_access(v_account_id) then
    raise exception using errcode = '42501', message = 'quote is unavailable';
  end if;

  update public.quotes
     set status = p_status
   where id = p_quote_id;

  if p_status = 'accepted'
    and v_previous_status <> 'accepted'
    and v_total_cents > 0 then
    insert into public.money_events (
      account_id,
      kind,
      amount_cents,
      source_type,
      source_id,
      description,
      created_by
    ) values (
      v_account_id,
      'earn',
      v_total_cents,
      'quote',
      p_quote_id,
      'Accepted quote ' || v_quote_number,
      auth.uid()
    )
    on conflict (account_id, source_type, source_id, kind)
      where source_id is not null
      do nothing;
  end if;
end;
$$;

revoke update (status) on public.quotes from authenticated;

revoke execute on function public.set_quote_status_with_money_event(
  uuid, public.quote_status
) from public, anon;
grant execute on function public.set_quote_status_with_money_event(
  uuid, public.quote_status
) to authenticated;
