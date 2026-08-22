-- Today automation: turn quote/return/warranty deadlines that already live
-- in the schema into public.actions rows automatically, instead of relying
-- on a human to notice and type them in.
--
-- Two halves:
--   1. generate_today_actions(account_id) -- an idempotent RPC the Today
--      screen calls on load (both web and mobile). Anti-duplication is a
--      real DB constraint (a partial unique index), not an application-side
--      "check then insert" -- so concurrent calls (e.g. two tabs, or web +
--      mobile open at once) can never double-insert. Runs as the calling
--      user (no SECURITY DEFINER): every source table it reads and the
--      actions table it writes are already RLS-scoped to has_account_access,
--      so there is nothing this function can see or write that the caller
--      couldn't already do directly.
--   2. Three small AFTER triggers that close an auto-generated action when
--      the underlying thing it was nagging about gets resolved elsewhere
--      (quote decided, return started, warranty claimed) -- so Today
--      doesn't keep asking about something the user already handled.

-- ---------------------------------------------------------------------------
-- 1. Anti-duplication key
-- ---------------------------------------------------------------------------

-- One action per (account, related entity, automation type), ever. If a
-- user dismisses an auto-generated action, generate_today_actions must not
-- resurrect it -- this index is what makes "on conflict do nothing" both
-- correct and atomic. Partial (related_type/related_id not null) so it
-- never constrains manual or AI-created actions, which have no related
-- entity.
create unique index actions_auto_dedup_idx
  on public.actions (account_id, related_type, related_id, type)
  where related_type is not null and related_id is not null;

-- ---------------------------------------------------------------------------
-- 2. Generator
-- ---------------------------------------------------------------------------

create or replace function public.generate_today_actions(p_account_id uuid)
returns setof public.actions
language plpgsql
as $$
begin
  if not public.has_account_access(p_account_id) then
    raise exception 'not authorized for this account';
  end if;

  return query
  insert into public.actions
    (account_id, type, title, description, due_at, related_type, related_id, status)
  select
    candidates.account_id,
    candidates.type,
    candidates.title,
    candidates.description,
    candidates.due_at,
    candidates.related_type,
    candidates.related_id,
    candidates.status
  from (
    -- Quote sent/viewed with no decision for 3+ days: nudge a follow-up.
    select
      q.account_id,
      'quote_follow_up'::text as type,
      'Follow up on quote ' || q.quote_number as title,
      'Sent ' || to_char(q.sent_at, 'Mon DD') || ' -- no response yet.' as description,
      (q.sent_at + interval '3 days') as due_at,
      'quote'::text as related_type,
      q.id as related_id,
      'open'::public.action_status as status
    from public.quotes q
    where q.account_id = p_account_id
      and q.status in ('sent', 'viewed')
      and q.sent_at is not null
      and q.sent_at <= now() - interval '3 days'

    union all

    -- Quote still open within 3 days of (or past) its valid_until date.
    select
      q.account_id,
      'quote_expiring'::text,
      'Quote ' || q.quote_number || ' is expiring',
      'Valid until ' || to_char(q.valid_until, 'Mon DD') || '.',
      q.valid_until::timestamptz,
      'quote'::text,
      q.id,
      'open'::public.action_status
    from public.quotes q
    where q.account_id = p_account_id
      and q.status in ('sent', 'viewed')
      and q.valid_until is not null
      and q.valid_until <= (current_date + interval '3 days')

    union all

    -- Purchase's return window closing within 5 days, item still owned,
    -- and no return has been started for it yet.
    select
      p.account_id,
      'return_window_expiring'::text,
      'Return window closing for ' || coalesce(i.name, 'an item'),
      'Return window closes ' || to_char(p.return_window_expires_at, 'Mon DD') || '.',
      p.return_window_expires_at::timestamptz,
      'purchase'::text,
      p.id,
      'open'::public.action_status
    from public.purchases p
    join public.items i on i.id = p.item_id
    where p.account_id = p_account_id
      and p.return_window_expires_at is not null
      and p.return_window_expires_at <= (current_date + interval '5 days')
      and i.status = 'owned'
      and not exists (
        select 1 from public.returns r where r.purchase_id = p.id
      )

    union all

    -- Warranty expiring within 30 days with no claim filed.
    select
      w.account_id,
      'warranty_expiring'::text,
      'Warranty expiring for ' || coalesce(i.name, 'an item'),
      'Coverage ends ' || to_char(w.expires_at, 'Mon DD') || '.',
      w.expires_at::timestamptz,
      'warranty'::text,
      w.id,
      'open'::public.action_status
    from public.warranties w
    join public.items i on i.id = w.item_id
    where w.account_id = p_account_id
      and w.expires_at is not null
      and w.expires_at <= (current_date + interval '30 days')
      and (w.claim_status is null or w.claim_status = '')
  ) as candidates
  on conflict (account_id, related_type, related_id, type)
    where related_type is not null and related_id is not null
  do nothing
  returning *;
end;
$$;

alter function public.generate_today_actions(uuid) set search_path = public;

revoke execute on function public.generate_today_actions(uuid) from public;
grant execute on function public.generate_today_actions(uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- 3. Lifecycle transitions: auto-close a generated action once the thing it
--    was about is resolved elsewhere, so Today doesn't keep nagging about
--    something the user already handled through the normal flow.
-- ---------------------------------------------------------------------------

create or replace function public.close_related_today_actions()
returns trigger
language plpgsql
as $$
begin
  if tg_table_name = 'quotes' then
    if new.status in ('accepted', 'declined', 'expired')
      and new.status is distinct from old.status then
      update public.actions
        set status = 'done', completed_at = now()
        where related_type = 'quote'
          and related_id = new.id
          and status in ('open', 'snoozed');
    end if;
    return new;
  end if;

  if tg_table_name = 'returns' then
    if new.purchase_id is not null then
      update public.actions
        set status = 'done', completed_at = now()
        where related_type = 'purchase'
          and related_id = new.purchase_id
          and status in ('open', 'snoozed');
    end if;
    return new;
  end if;

  if tg_table_name = 'warranties' then
    if new.claim_status is not null and new.claim_status <> ''
      and (old.claim_status is null or old.claim_status = '') then
      update public.actions
        set status = 'done', completed_at = now()
        where related_type = 'warranty'
          and related_id = new.id
          and status in ('open', 'snoozed');
    end if;
    return new;
  end if;

  return new;
end;
$$;

alter function public.close_related_today_actions() set search_path = public;

create trigger close_today_actions_on_quote_decision
  after update of status on public.quotes
  for each row execute function public.close_related_today_actions();

create trigger close_today_actions_on_return_started
  after insert on public.returns
  for each row execute function public.close_related_today_actions();

create trigger close_today_actions_on_warranty_claim
  after update of claim_status on public.warranties
  for each row execute function public.close_related_today_actions();
