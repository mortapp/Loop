-- Atomic item-photo metadata operations. Updating the whole photos array from
-- a client-side snapshot loses concurrent uploads/removals, so both clients
-- now call these row-locking, account-scoped functions instead.

create or replace function public.attach_item_photo(
  p_account_id uuid,
  p_item_id uuid,
  p_object_path text
)
returns text[]
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_photos text[];
begin
  if auth.uid() is null or not public.has_account_access(p_account_id) then
    raise exception using errcode = '42501', message = 'account access denied';
  end if;

  if p_object_path is null
     or char_length(p_object_path) > 1024
     or p_object_path not like p_account_id::text || '/' || p_item_id::text || '/%'
     or cardinality(string_to_array(p_object_path, '/')) <> 3
     or p_object_path like '%..%'
     or position(chr(92) in p_object_path) > 0
  then
    raise exception using errcode = '22023', message = 'invalid item photo path';
  end if;

  if not exists (
    select 1
    from storage.objects as object
    where object.bucket_id = 'item-photos'
      and object.name = p_object_path
  ) then
    raise exception using errcode = '23503', message = 'item photo object not found';
  end if;

  update public.items
  set photos = case
    when p_object_path = any (photos) then photos
    else array_append(photos, p_object_path)
  end
  where id = p_item_id
    and account_id = p_account_id
  returning photos into v_photos;

  if not found then
    raise exception using errcode = '42501', message = 'item access denied';
  end if;

  return v_photos;
end;
$$;

create or replace function public.detach_item_photo(
  p_account_id uuid,
  p_item_id uuid,
  p_object_path text
)
returns text[]
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_photos text[];
begin
  if auth.uid() is null or not public.has_account_access(p_account_id) then
    raise exception using errcode = '42501', message = 'account access denied';
  end if;

  if p_object_path is null
     or char_length(p_object_path) > 1024
     or p_object_path not like p_account_id::text || '/' || p_item_id::text || '/%'
     or cardinality(string_to_array(p_object_path, '/')) <> 3
     or p_object_path like '%..%'
     or position(chr(92) in p_object_path) > 0
  then
    raise exception using errcode = '22023', message = 'invalid item photo path';
  end if;

  update public.items
  set photos = array_remove(photos, p_object_path)
  where id = p_item_id
    and account_id = p_account_id
  returning photos into v_photos;

  if not found then
    raise exception using errcode = '42501', message = 'item access denied';
  end if;

  return v_photos;
end;
$$;

revoke all on function public.attach_item_photo(uuid, uuid, text) from public;
revoke all on function public.detach_item_photo(uuid, uuid, text) from public;

grant execute on function public.attach_item_photo(uuid, uuid, text) to authenticated;
grant execute on function public.detach_item_photo(uuid, uuid, text) to authenticated;
