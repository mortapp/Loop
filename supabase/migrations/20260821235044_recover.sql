-- RECOVER / ResellLens: valuations -> listings -> sales.
-- Strongly typed domain extension on top of the shared core primitives.

create type public.valuation_source as enum ('ai', 'manual', 'marketplace');

create type public.listing_status as enum (
  'draft', 'active', 'sold', 'removed'
);

create table public.valuations (
  id uuid primary key default gen_random_uuid(),
  account_id uuid not null references public.accounts (id) on delete cascade,
  item_id uuid not null references public.items (id) on delete cascade,
  source public.valuation_source not null default 'manual',
  estimated_value_cents bigint not null,
  confidence numeric,
  valued_at timestamptz not null default now(),
  created_by uuid references public.profiles (id),
  created_at timestamptz not null default now()
);

create index valuations_account_id_idx on public.valuations (account_id);
create index valuations_item_id_idx on public.valuations (item_id);

alter table public.valuations enable row level security;

-- A running history of estimates: readable and insertable, never mutated.
create policy "valuations_select"
  on public.valuations for select
  to authenticated
  using (public.has_account_access(account_id));

create policy "valuations_insert"
  on public.valuations for insert
  to authenticated
  with check (public.has_account_access(account_id));

create table public.listings (
  id uuid primary key default gen_random_uuid(),
  account_id uuid not null references public.accounts (id) on delete cascade,
  item_id uuid not null references public.items (id) on delete cascade,
  marketplace text not null,
  status public.listing_status not null default 'draft',
  list_price_cents bigint,
  listing_url text,
  published_at timestamptz,
  created_by uuid references public.profiles (id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index listings_account_id_idx on public.listings (account_id);
create index listings_item_id_idx on public.listings (item_id);
create index listings_status_idx on public.listings (status);

create trigger set_listings_updated_at
  before update on public.listings
  for each row execute function public.set_updated_at();

alter table public.listings enable row level security;

create policy "listings_access"
  on public.listings for all
  to authenticated
  using (public.has_account_access(account_id))
  with check (public.has_account_access(account_id));

create table public.sales (
  id uuid primary key default gen_random_uuid(),
  account_id uuid not null references public.accounts (id) on delete cascade,
  item_id uuid not null references public.items (id) on delete cascade,
  listing_id uuid references public.listings (id) on delete set null,
  buyer_contact_id uuid references public.contacts (id) on delete set null,
  sale_price_cents bigint not null,
  fees_cents bigint not null default 0,
  net_amount_cents bigint not null,
  sold_at timestamptz not null default now(),
  created_by uuid references public.profiles (id),
  created_at timestamptz not null default now()
);

create index sales_account_id_idx on public.sales (account_id);
create index sales_item_id_idx on public.sales (item_id);

alter table public.sales enable row level security;

-- A financial record: readable, insertable, and correctable, but never
-- deleted (see money_events, which is the append-only ledger of record).
create policy "sales_select"
  on public.sales for select
  to authenticated
  using (public.has_account_access(account_id));

create policy "sales_insert"
  on public.sales for insert
  to authenticated
  with check (public.has_account_access(account_id));

create policy "sales_update"
  on public.sales for update
  to authenticated
  using (public.has_account_access(account_id))
  with check (public.has_account_access(account_id));

grant select, insert on public.valuations to authenticated;
grant select, insert, update, delete on public.listings to authenticated;
grant select, insert, update on public.sales to authenticated;
