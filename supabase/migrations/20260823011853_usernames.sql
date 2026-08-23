-- Real @username handles, added at the owner's explicit request during
-- the native Google-account-setup flow (see apps/web/src/app/auth/
-- complete-profile and apps/mobile/lib/features/onboarding). Separate
-- from profiles.display_name (a free-text friendly label, already
-- existed) -- username is the normalized, globally-unique handle.
--
-- Database-authoritative: the unique index + check constraint are what
-- actually prevent a collision, never just client-side or RPC-level
-- pre-checks. is_username_available() below is a pre-check for UX only.

alter table public.profiles add column username text;

alter table public.profiles add constraint profiles_username_format check (
  username is null or username ~ '^[a-z0-9_]{3,20}$'
);

-- Reserved so a username can never collide with a real route, system
-- concept, or obviously-official-sounding handle. Stored as a constant
-- list here and mirrored in is_username_available() below -- the
-- constraint is what's actually authoritative; the function exists so
-- the UI can give a same-list pre-check without a round trip that fails.
alter table public.profiles add constraint profiles_username_not_reserved check (
  username is null or username not in (
    'admin', 'root', 'loop', 'support', 'api', 'www', 'help', 'settings',
    'profile', 'account', 'accounts', 'sign-in', 'sign-up', 'signin',
    'signup', 'about', 'null', 'undefined', 'system', 'today', 'money',
    'sell', 'business', 'ai', 'you', 'me', 'owner', 'staff', 'moderator',
    'mod', 'test', 'official', 'security', 'billing'
  )
);

-- Storage is already lowercase (enforced by the format check's character
-- class), so a plain unique index is case-insensitive in effect without
-- needing a functional index on lower(username).
create unique index profiles_username_unique_idx on public.profiles (username) where username is not null;

-- Pre-check for the onboarding UI's live "available"/"taken"/"invalid"
-- state. SECURITY DEFINER because checking availability necessarily
-- means testing existence against *other* users' usernames, which
-- profiles' own RLS (self-or-business-peers) wouldn't allow -- but this
-- leaks nothing beyond a boolean, never row contents.
create or replace function public.is_username_available(candidate text)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select
    candidate ~ '^[a-z0-9_]{3,20}$'
    and candidate not in (
      'admin', 'root', 'loop', 'support', 'api', 'www', 'help', 'settings',
      'profile', 'account', 'accounts', 'sign-in', 'sign-up', 'signin',
      'signup', 'about', 'null', 'undefined', 'system', 'today', 'money',
      'sell', 'business', 'ai', 'you', 'me', 'owner', 'staff', 'moderator',
      'mod', 'test', 'official', 'security', 'billing'
    )
    and not exists (
      select 1 from public.profiles p where p.username = candidate
    );
$$;

alter function public.is_username_available(text) set search_path = public;

revoke execute on function public.is_username_available(text) from public;
grant execute on function public.is_username_available(text) to authenticated;

-- No new RLS policy needed: profiles_update_self already lets a user
-- update any column on their own row (using/with check id = auth.uid()),
-- username included -- the constraint + unique index above are what
-- actually enforce correctness on write.
