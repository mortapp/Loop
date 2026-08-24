-- Quote creation already validates account ownership, line items, and totals.
-- Make that RPC the only creation path so modified clients cannot bypass it.

alter function public.create_quote_with_line_items(
  uuid, uuid, uuid, text, bigint, bigint, bigint, uuid, jsonb
) security definer;

revoke insert, delete on public.quotes from authenticated;
revoke update on public.quotes from authenticated;
grant update (status) on public.quotes to authenticated;

revoke insert, update, delete on public.quote_line_items from authenticated;

create or replace function private.stamp_quote_status_timestamps()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
  if new.status is distinct from old.status then
    if new.status = 'sent' and old.sent_at is null then
      new.sent_at := pg_catalog.now();
    end if;
    if new.status = 'accepted' and old.accepted_at is null then
      new.accepted_at := pg_catalog.now();
    end if;
  end if;
  return new;
end;
$$;

revoke execute on function private.stamp_quote_status_timestamps()
  from public, anon, authenticated;

create trigger stamp_quote_status_timestamps
  before update of status on public.quotes
  for each row execute function private.stamp_quote_status_timestamps();
