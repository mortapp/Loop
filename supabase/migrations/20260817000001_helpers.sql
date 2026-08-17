-- LOOP core helpers: extensions, updated_at trigger, identity helpers.
-- These are shared by every domain migration that follows.

create extension if not exists pgcrypto;

-- Generic updated_at maintenance trigger, reused by every table below.
create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

-- The signed-in profile id. profiles.id == auth.users.id (1:1), so this is
-- just auth.uid() named for readability at call sites.
create or replace function public.current_profile_id()
returns uuid
language sql
stable
as $$
  select auth.uid();
$$;
