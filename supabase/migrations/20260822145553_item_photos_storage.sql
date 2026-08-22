-- Storage: item photos, mirroring the "documents" bucket's pattern
-- (20260817000007_storage.sql) exactly -- partitioned by account_id as the
-- first path segment (e.g. "<account_id>/<item_id>/<file_name>"), guarded
-- by the same has_account_access() rule used everywhere else account-scoped
-- data is protected. Private (not public) -- reads go through signed URLs
-- generated server-side/client-side by an authenticated, authorized caller,
-- never a public bucket URL.

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'item-photos',
  'item-photos',
  false,
  8388608, -- 8 MiB
  array['image/jpeg', 'image/png', 'image/webp', 'image/heic', 'image/heif']
)
on conflict (id) do nothing;

create policy "item_photos_bucket_access"
  on storage.objects for all
  to authenticated
  using (
    bucket_id = 'item-photos'
    and public.has_account_access((storage.foldername(name))[1]::uuid)
  )
  with check (
    bucket_id = 'item-photos'
    and public.has_account_access((storage.foldername(name))[1]::uuid)
  );
