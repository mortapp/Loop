-- LOOP identity: profiles, businesses, business membership, and the unified
-- "account" concept that every domain table hangs off of.
--
-- An account is the single acting context shared by MAKE/PROTECT/RECOVER:
-- either a person's personal account, or a business account. Every domain
-- row (contacts, items, quotes, returns, listings, ...) belongs to exactly
-- one account, so RLS is enforced in one place via has_account_access().

create type public.account_type as enum ('personal', 'business');
create type public.member_role as enum ('owner', 'admin', 'member');
create type public.member_status as enum ('invited', 'active', 'removed');
create type public.account_mode as enum ('personal', 'business', 'both');

-- ---------------------------------------------------------------------------
-- profiles
-- ---------------------------------------------------------------------------

create table public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  email text not null,
  display_name text,
  avatar_url text,
  default_mode public.account_mode not null default 'personal',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create trigger set_profiles_updated_at
  before update on public.profiles
  for each row execute function public.set_updated_at();

alter table public.profiles enable row level security;

-- profiles policies are declared after business_members below, since the
-- peer-visibility policy needs it (via a helper function) to exist first.

-- ---------------------------------------------------------------------------
-- businesses
-- ---------------------------------------------------------------------------

create table public.businesses (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  slug text not null unique,
  created_by uuid not null references public.profiles (id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create trigger set_businesses_updated_at
  before update on public.businesses
  for each row execute function public.set_updated_at();

alter table public.businesses enable row level security;

create table public.business_members (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses (id) on delete cascade,
  profile_id uuid not null references public.profiles (id) on delete cascade,
  role public.member_role not null default 'member',
  status public.member_status not null default 'active',
  invited_by uuid references public.profiles (id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (business_id, profile_id)
);

create trigger set_business_members_updated_at
  before update on public.business_members
  for each row execute function public.set_updated_at();

alter table public.business_members enable row level security;

-- ---------------------------------------------------------------------------
-- Membership helper functions.
--
-- These MUST be security definer. business_members' own RLS policies need
-- to check business_members membership, and a policy on table T cannot
-- query T directly from within itself (Postgres reports "infinite
-- recursion detected in policy"). Routing the check through a security
-- definer function breaks the cycle: the function runs as its owner
-- (a superuser locally / the migration role), which bypasses RLS, so the
-- lookup inside it is a plain, non-recursive query.
-- ---------------------------------------------------------------------------

create or replace function public.is_active_business_member(target_business_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.business_members bm
    where bm.business_id = target_business_id
      and bm.profile_id = auth.uid()
      and bm.status = 'active'
  );
$$;

create or replace function public.is_business_admin(target_business_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.business_members bm
    where bm.business_id = target_business_id
      and bm.profile_id = auth.uid()
      and bm.status = 'active'
      and bm.role in ('owner', 'admin')
  );
$$;

create or replace function public.shares_active_business(target_profile_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.business_members bm_self
    join public.business_members bm_peer
      on bm_peer.business_id = bm_self.business_id
    where bm_self.profile_id = auth.uid()
      and bm_self.status = 'active'
      and bm_peer.profile_id = target_profile_id
      and bm_peer.status = 'active'
  );
$$;

-- `created_by = auth.uid()` is included (not just membership) because an
-- INSERT ... RETURNING re-checks the SELECT policy against the new row
-- before the AFTER INSERT trigger below has created the owner's
-- business_members row — without it, creating a business via a client
-- that asks for the row back (e.g. `.insert().select()`) would 42501.
create policy "businesses_select_members"
  on public.businesses for select
  to authenticated
  using (created_by = auth.uid() or public.is_active_business_member(id));

create policy "businesses_insert_authenticated"
  on public.businesses for insert
  to authenticated
  with check (created_by = auth.uid());

create policy "businesses_update_owner_admin"
  on public.businesses for update
  to authenticated
  using (public.is_business_admin(id));

create policy "business_members_select_peers"
  on public.business_members for select
  to authenticated
  using (public.is_active_business_member(business_id));

create policy "business_members_manage_owner_admin"
  on public.business_members for all
  to authenticated
  using (public.is_business_admin(business_id))
  with check (public.is_business_admin(business_id));

-- A profile may always see and manage their own membership row (accept an
-- invite, leave a business) even before they'd otherwise qualify above.
create policy "business_members_self_manage"
  on public.business_members for all
  to authenticated
  using (profile_id = auth.uid())
  with check (profile_id = auth.uid());

-- profiles policies (declared here so the peer-visibility check can use
-- shares_active_business(), which needed business_members to exist above).

create policy "profiles_select_self_or_business_peers"
  on public.profiles for select
  to authenticated
  using (
    id = auth.uid()
    or public.shares_active_business(id)
  );

create policy "profiles_update_self"
  on public.profiles for update
  to authenticated
  using (id = auth.uid())
  with check (id = auth.uid());

-- ---------------------------------------------------------------------------
-- accounts: the unified acting context (personal xor business)
-- ---------------------------------------------------------------------------

create table public.accounts (
  id uuid primary key default gen_random_uuid(),
  type public.account_type not null,
  owner_profile_id uuid references public.profiles (id) on delete cascade,
  business_id uuid references public.businesses (id) on delete cascade,
  created_at timestamptz not null default now(),
  constraint accounts_owner_matches_type check (
    (type = 'personal' and owner_profile_id is not null and business_id is null)
    or (type = 'business' and business_id is not null and owner_profile_id is null)
  ),
  unique (owner_profile_id),
  unique (business_id)
);

alter table public.accounts enable row level security;

-- Central access check reused by every domain table's RLS policies.
create or replace function public.has_account_access(target_account_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.accounts a
    where a.id = target_account_id
      and (
        (a.type = 'personal' and a.owner_profile_id = auth.uid())
        or (a.type = 'business' and public.is_active_business_member(a.business_id))
      )
  );
$$;

create policy "accounts_select_accessible"
  on public.accounts for select
  to authenticated
  using (public.has_account_access(id));

-- ---------------------------------------------------------------------------
-- auto-provisioning: auth.users -> profiles -> personal account
--                     businesses -> owner membership -> business account
-- ---------------------------------------------------------------------------

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, email, display_name)
  values (new.id, new.email, new.raw_user_meta_data ->> 'display_name')
  on conflict (id) do nothing;
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

create or replace function public.handle_new_profile()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.accounts (type, owner_profile_id)
  values ('personal', new.id);
  return new;
end;
$$;

create trigger on_profile_created
  after insert on public.profiles
  for each row execute function public.handle_new_profile();

create or replace function public.handle_new_business()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.accounts (type, business_id)
  values ('business', new.id);

  insert into public.business_members (business_id, profile_id, role, status)
  values (new.id, new.created_by, 'owner', 'active');

  return new;
end;
$$;

create trigger on_business_created
  after insert on public.businesses
  for each row execute function public.handle_new_business();

-- ---------------------------------------------------------------------------
-- Grants. RLS policies decide *which rows*; these decide *which
-- operations* a role may attempt at all. Supabase does not auto-expose
-- newly created tables to the `authenticated` role, so every table needs
-- an explicit grant alongside its policies.
-- ---------------------------------------------------------------------------

grant usage on schema public to authenticated;

grant select, update on public.profiles to authenticated;
grant select, insert, update on public.businesses to authenticated;
grant select, insert, update, delete on public.business_members to authenticated;
grant select on public.accounts to authenticated;
