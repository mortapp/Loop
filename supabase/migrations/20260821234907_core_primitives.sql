-- LOOP core primitives shared by every domain engine: contacts, items,
-- documents, money events, unified actions, and the domain event log.
--
-- All access control follows one pattern: every row belongs to an
-- account_id, and public.has_account_access() (defined in
-- 20260817000002_identity.sql) decides who may touch it.

create type public.item_status as enum (
  'owned', 'returned', 'listed', 'sold', 'disposed'
);

create type public.document_kind as enum (
  'receipt', 'invoice', 'quote', 'warranty', 'listing', 'other'
);

create type public.money_event_kind as enum (
  'earn', 'spend', 'refund', 'fee', 'recovered'
);

create type public.action_status as enum (
  'open', 'snoozed', 'done', 'dismissed'
);

-- ---------------------------------------------------------------------------
-- contacts
-- ---------------------------------------------------------------------------

create table public.contacts (
  id uuid primary key default gen_random_uuid(),
  account_id uuid not null references public.accounts (id) on delete cascade,
  display_name text not null,
  email text,
  phone text,
  company text,
  notes text,
  tags text[] not null default '{}',
  created_by uuid references public.profiles (id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index contacts_account_id_idx on public.contacts (account_id);

create trigger set_contacts_updated_at
  before update on public.contacts
  for each row execute function public.set_updated_at();

alter table public.contacts enable row level security;

create policy "contacts_access"
  on public.contacts for all
  to authenticated
  using (public.has_account_access(account_id))
  with check (public.has_account_access(account_id));

-- ---------------------------------------------------------------------------
-- items: the OWN anchor entity that MAKE/PROTECT/RECOVER all hang off of
-- ---------------------------------------------------------------------------

create table public.items (
  id uuid primary key default gen_random_uuid(),
  account_id uuid not null references public.accounts (id) on delete cascade,
  name text not null,
  description text,
  category text,
  condition text,
  brand text,
  model text,
  serial_number text,
  purchase_price_cents bigint,
  purchase_date date,
  photos text[] not null default '{}',
  status public.item_status not null default 'owned',
  created_by uuid references public.profiles (id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index items_account_id_idx on public.items (account_id);
create index items_status_idx on public.items (status);

create trigger set_items_updated_at
  before update on public.items
  for each row execute function public.set_updated_at();

alter table public.items enable row level security;

create policy "items_access"
  on public.items for all
  to authenticated
  using (public.has_account_access(account_id))
  with check (public.has_account_access(account_id));

-- ---------------------------------------------------------------------------
-- documents: receipts, invoices, quotes, warranties, listing screenshots...
-- storage_path points into the "documents" Storage bucket.
-- ---------------------------------------------------------------------------

create table public.documents (
  id uuid primary key default gen_random_uuid(),
  account_id uuid not null references public.accounts (id) on delete cascade,
  item_id uuid references public.items (id) on delete set null,
  kind public.document_kind not null default 'other',
  related_type text,
  related_id uuid,
  storage_path text not null,
  file_name text not null,
  mime_type text,
  size_bytes bigint,
  created_by uuid references public.profiles (id),
  created_at timestamptz not null default now()
);

create index documents_account_id_idx on public.documents (account_id);
create index documents_item_id_idx on public.documents (item_id);
create index documents_related_idx on public.documents (related_type, related_id);

alter table public.documents enable row level security;

create policy "documents_access"
  on public.documents for all
  to authenticated
  using (public.has_account_access(account_id))
  with check (public.has_account_access(account_id));

-- ---------------------------------------------------------------------------
-- money_events: the append-only value ledger (EARN / BUY / RETURN / RESELL)
-- ---------------------------------------------------------------------------

create table public.money_events (
  id uuid primary key default gen_random_uuid(),
  account_id uuid not null references public.accounts (id) on delete cascade,
  item_id uuid references public.items (id) on delete set null,
  kind public.money_event_kind not null,
  amount_cents bigint not null,
  currency text not null default 'USD',
  occurred_at timestamptz not null default now(),
  source_type text,
  source_id uuid,
  description text,
  created_by uuid references public.profiles (id),
  created_at timestamptz not null default now()
);

create index money_events_account_id_idx on public.money_events (account_id);
create index money_events_item_id_idx on public.money_events (item_id);
create index money_events_occurred_at_idx on public.money_events (occurred_at);

alter table public.money_events enable row level security;

-- Append-only ledger: readable and insertable, never updated or deleted.
create policy "money_events_select"
  on public.money_events for select
  to authenticated
  using (public.has_account_access(account_id));

create policy "money_events_insert"
  on public.money_events for insert
  to authenticated
  with check (public.has_account_access(account_id));

-- ---------------------------------------------------------------------------
-- actions: the unified queue that powers the Today engine
-- ---------------------------------------------------------------------------

create table public.actions (
  id uuid primary key default gen_random_uuid(),
  account_id uuid not null references public.accounts (id) on delete cascade,
  type text not null,
  title text not null,
  description text,
  status public.action_status not null default 'open',
  due_at timestamptz,
  related_type text,
  related_id uuid,
  assigned_to uuid references public.profiles (id),
  created_by uuid references public.profiles (id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  completed_at timestamptz
);

create index actions_account_id_idx on public.actions (account_id);
create index actions_status_due_idx on public.actions (status, due_at);
create index actions_related_idx on public.actions (related_type, related_id);

create trigger set_actions_updated_at
  before update on public.actions
  for each row execute function public.set_updated_at();

alter table public.actions enable row level security;

create policy "actions_access"
  on public.actions for all
  to authenticated
  using (public.has_account_access(account_id))
  with check (public.has_account_access(account_id));

-- ---------------------------------------------------------------------------
-- events: append-only domain event log (drives Today feed + automations)
-- ---------------------------------------------------------------------------

create table public.events (
  id uuid primary key default gen_random_uuid(),
  account_id uuid not null references public.accounts (id) on delete cascade,
  type text not null,
  payload jsonb not null default '{}'::jsonb,
  related_type text,
  related_id uuid,
  actor_profile_id uuid references public.profiles (id),
  occurred_at timestamptz not null default now(),
  created_at timestamptz not null default now()
);

create index events_account_id_idx on public.events (account_id);
create index events_occurred_at_idx on public.events (occurred_at);
create index events_related_idx on public.events (related_type, related_id);

alter table public.events enable row level security;

-- Append-only log: readable and insertable, never updated or deleted.
create policy "events_select"
  on public.events for select
  to authenticated
  using (public.has_account_access(account_id));

create policy "events_insert"
  on public.events for insert
  to authenticated
  with check (public.has_account_access(account_id));

-- ---------------------------------------------------------------------------
-- Grants (see 20260817000002_identity.sql for why these are needed).
-- ---------------------------------------------------------------------------

grant select, insert, update, delete on public.contacts to authenticated;
grant select, insert, update, delete on public.items to authenticated;
grant select, insert, update, delete on public.documents to authenticated;
grant select, insert on public.money_events to authenticated;
grant select, insert, update, delete on public.actions to authenticated;
grant select, insert on public.events to authenticated;
