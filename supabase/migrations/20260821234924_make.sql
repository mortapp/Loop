-- MAKE / QuoteCloser: leads -> opportunities -> quotes.
-- Strongly typed domain extension on top of the shared core primitives
-- (accounts, contacts, items, documents, money_events, actions, events).

create type public.lead_status as enum (
  'new', 'contacted', 'qualified', 'disqualified', 'converted'
);

create type public.opportunity_stage as enum (
  'new', 'qualifying', 'quoted', 'negotiating', 'won', 'lost'
);

create type public.quote_status as enum (
  'draft', 'sent', 'viewed', 'accepted', 'declined', 'expired'
);

create table public.leads (
  id uuid primary key default gen_random_uuid(),
  account_id uuid not null references public.accounts (id) on delete cascade,
  contact_id uuid references public.contacts (id) on delete set null,
  source text,
  status public.lead_status not null default 'new',
  notes text,
  created_by uuid references public.profiles (id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index leads_account_id_idx on public.leads (account_id);

create trigger set_leads_updated_at
  before update on public.leads
  for each row execute function public.set_updated_at();

alter table public.leads enable row level security;

create policy "leads_access"
  on public.leads for all
  to authenticated
  using (public.has_account_access(account_id))
  with check (public.has_account_access(account_id));

create table public.opportunities (
  id uuid primary key default gen_random_uuid(),
  account_id uuid not null references public.accounts (id) on delete cascade,
  contact_id uuid references public.contacts (id) on delete set null,
  lead_id uuid references public.leads (id) on delete set null,
  title text not null,
  stage public.opportunity_stage not null default 'new',
  estimated_value_cents bigint,
  created_by uuid references public.profiles (id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index opportunities_account_id_idx on public.opportunities (account_id);
create index opportunities_stage_idx on public.opportunities (stage);

create trigger set_opportunities_updated_at
  before update on public.opportunities
  for each row execute function public.set_updated_at();

alter table public.opportunities enable row level security;

create policy "opportunities_access"
  on public.opportunities for all
  to authenticated
  using (public.has_account_access(account_id))
  with check (public.has_account_access(account_id));

create table public.quotes (
  id uuid primary key default gen_random_uuid(),
  account_id uuid not null references public.accounts (id) on delete cascade,
  opportunity_id uuid references public.opportunities (id) on delete set null,
  contact_id uuid references public.contacts (id) on delete set null,
  quote_number text not null,
  status public.quote_status not null default 'draft',
  subtotal_cents bigint not null default 0,
  tax_cents bigint not null default 0,
  total_cents bigint not null default 0,
  currency text not null default 'USD',
  valid_until date,
  sent_at timestamptz,
  accepted_at timestamptz,
  created_by uuid references public.profiles (id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (account_id, quote_number)
);

create index quotes_account_id_idx on public.quotes (account_id);
create index quotes_status_idx on public.quotes (status);

create trigger set_quotes_updated_at
  before update on public.quotes
  for each row execute function public.set_updated_at();

alter table public.quotes enable row level security;

create policy "quotes_access"
  on public.quotes for all
  to authenticated
  using (public.has_account_access(account_id))
  with check (public.has_account_access(account_id));

create table public.quote_line_items (
  id uuid primary key default gen_random_uuid(),
  quote_id uuid not null references public.quotes (id) on delete cascade,
  description text not null,
  quantity numeric not null default 1,
  unit_price_cents bigint not null default 0,
  position integer not null default 0
);

create index quote_line_items_quote_id_idx on public.quote_line_items (quote_id);

alter table public.quote_line_items enable row level security;

-- Line items have no account_id of their own; access follows the parent quote.
create policy "quote_line_items_access"
  on public.quote_line_items for all
  to authenticated
  using (
    exists (
      select 1 from public.quotes q
      where q.id = quote_line_items.quote_id
        and public.has_account_access(q.account_id)
    )
  )
  with check (
    exists (
      select 1 from public.quotes q
      where q.id = quote_line_items.quote_id
        and public.has_account_access(q.account_id)
    )
  );

grant select, insert, update, delete on public.leads to authenticated;
grant select, insert, update, delete on public.opportunities to authenticated;
grant select, insert, update, delete on public.quotes to authenticated;
grant select, insert, update, delete on public.quote_line_items to authenticated;
