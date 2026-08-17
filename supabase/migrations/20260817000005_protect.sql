-- PROTECT / ReturnGuard: purchases -> returns / warranties.
-- Strongly typed domain extension on top of the shared core primitives.

create type public.return_status as enum (
  'initiated', 'shipped', 'received', 'refunded', 'denied'
);

create table public.purchases (
  id uuid primary key default gen_random_uuid(),
  account_id uuid not null references public.accounts (id) on delete cascade,
  item_id uuid references public.items (id) on delete set null,
  vendor_contact_id uuid references public.contacts (id) on delete set null,
  vendor_name text,
  purchase_date date,
  price_cents bigint,
  receipt_document_id uuid references public.documents (id) on delete set null,
  warranty_expires_at date,
  return_window_expires_at date,
  created_by uuid references public.profiles (id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index purchases_account_id_idx on public.purchases (account_id);
create index purchases_item_id_idx on public.purchases (item_id);

create trigger set_purchases_updated_at
  before update on public.purchases
  for each row execute function public.set_updated_at();

alter table public.purchases enable row level security;

create policy "purchases_access"
  on public.purchases for all
  to authenticated
  using (public.has_account_access(account_id))
  with check (public.has_account_access(account_id));

create table public.returns (
  id uuid primary key default gen_random_uuid(),
  account_id uuid not null references public.accounts (id) on delete cascade,
  item_id uuid not null references public.items (id) on delete cascade,
  purchase_id uuid references public.purchases (id) on delete set null,
  reason text,
  status public.return_status not null default 'initiated',
  refund_amount_cents bigint,
  initiated_at timestamptz not null default now(),
  resolved_at timestamptz,
  created_by uuid references public.profiles (id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index returns_account_id_idx on public.returns (account_id);
create index returns_item_id_idx on public.returns (item_id);
create index returns_status_idx on public.returns (status);

create trigger set_returns_updated_at
  before update on public.returns
  for each row execute function public.set_updated_at();

alter table public.returns enable row level security;

create policy "returns_access"
  on public.returns for all
  to authenticated
  using (public.has_account_access(account_id))
  with check (public.has_account_access(account_id));

create table public.warranties (
  id uuid primary key default gen_random_uuid(),
  account_id uuid not null references public.accounts (id) on delete cascade,
  item_id uuid not null references public.items (id) on delete cascade,
  provider text,
  coverage_summary text,
  starts_at date,
  expires_at date,
  claim_status text,
  created_by uuid references public.profiles (id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index warranties_account_id_idx on public.warranties (account_id);
create index warranties_item_id_idx on public.warranties (item_id);
create index warranties_expires_at_idx on public.warranties (expires_at);

create trigger set_warranties_updated_at
  before update on public.warranties
  for each row execute function public.set_updated_at();

alter table public.warranties enable row level security;

create policy "warranties_access"
  on public.warranties for all
  to authenticated
  using (public.has_account_access(account_id))
  with check (public.has_account_access(account_id));

grant select, insert, update, delete on public.purchases to authenticated;
grant select, insert, update, delete on public.returns to authenticated;
grant select, insert, update, delete on public.warranties to authenticated;
