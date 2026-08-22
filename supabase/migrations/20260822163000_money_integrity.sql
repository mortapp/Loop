-- Money integrity: a real DB-level invariant plus one canonical
-- MADE/PROTECTED/RECOVERED/SPENT/FEES/NET formula, replacing two
-- independent client-side reimplementations that were only kept in sync
-- by a "mirrors X" comment.

-- ---------------------------------------------------------------------------
-- 1. amount_cents is always a positive magnitude; `kind` alone carries
--    direction. Every existing caller (the AI tool, both manual-entry
--    forms) already enforces this client-side, but nothing in the schema
--    did -- a direct insert (a future RPC, a script, a bug) could silently
--    store a zero or negative amount and corrupt every downstream total.
-- ---------------------------------------------------------------------------

alter table public.money_events
  add constraint money_events_amount_cents_positive check (amount_cents > 0);

-- ---------------------------------------------------------------------------
-- 2. Canonical totals. Previously reimplemented independently in
--    apps/web/src/app/(app)/money/page.tsx (KIND_SIGN reduce) and
--    apps/mobile/lib/features/money/models/money_event.dart
--    (moneyEventKindSign) -- this function is now the one place the
--    formula lives; both clients call it instead of re-deriving it.
--
--    kind -> label mapping matches the product's existing MAKE/PROTECT/
--    RECOVER story: earn -> MADE, refund -> PROTECTED, recovered ->
--    RECOVERED, spend -> SPENT, fee -> FEES.
--    NET = MADE + PROTECTED + RECOVERED - SPENT - FEES.
--
--    No SECURITY DEFINER: runs as the caller, and reads through the same
--    has_account_access() gate money_events' own RLS already enforces --
--    explicitly re-checked here too so an unauthorized account_id raises
--    instead of silently returning all-zero totals.
-- ---------------------------------------------------------------------------

create or replace function public.account_money_totals(p_account_id uuid)
returns table (
  made_cents bigint,
  protected_cents bigint,
  recovered_cents bigint,
  spent_cents bigint,
  fees_cents bigint,
  net_cents bigint
)
language plpgsql
stable
as $$
begin
  if not public.has_account_access(p_account_id) then
    raise exception 'not authorized for this account';
  end if;

  return query
  select
    coalesce(sum(amount_cents) filter (where kind = 'earn'), 0)::bigint,
    coalesce(sum(amount_cents) filter (where kind = 'refund'), 0)::bigint,
    coalesce(sum(amount_cents) filter (where kind = 'recovered'), 0)::bigint,
    coalesce(sum(amount_cents) filter (where kind = 'spend'), 0)::bigint,
    coalesce(sum(amount_cents) filter (where kind = 'fee'), 0)::bigint,
    (
      coalesce(sum(amount_cents) filter (where kind in ('earn', 'refund', 'recovered')), 0)
      - coalesce(sum(amount_cents) filter (where kind in ('spend', 'fee')), 0)
    )::bigint
  from public.money_events
  where account_id = p_account_id;
end;
$$;

alter function public.account_money_totals(uuid) set search_path = public;

revoke execute on function public.account_money_totals(uuid) from public;
grant execute on function public.account_money_totals(uuid) to authenticated;
