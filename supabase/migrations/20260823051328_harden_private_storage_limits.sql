-- Private Storage hardening: bounded uploads, narrow document MIME types,
-- fail-closed path parsing, and database metadata/path consistency.

update storage.buckets
set public = false,
    file_size_limit = 12582912, -- 12 MiB
    allowed_mime_types = array[
      'application/pdf',
      'image/jpeg',
      'image/png',
      'image/webp',
      'image/heic',
      'image/heif'
    ]
where id = 'documents';

update storage.buckets
set public = false,
    file_size_limit = 8388608, -- 8 MiB
    allowed_mime_types = array[
      'image/jpeg',
      'image/png',
      'image/webp',
      'image/heic',
      'image/heif'
    ]
where id = 'item-photos';

alter table public.documents
  add constraint documents_storage_path_account_prefix
  check (storage_path like account_id::text || '/%');

alter table public.documents
  add constraint documents_file_name_length
  check (char_length(file_name) between 1 and 255);

alter table public.documents
  add constraint documents_size_bytes_bounds
  check (size_bytes is null or size_bytes between 1 and 12582912);

alter table public.documents
  add constraint documents_mime_type_allowed
  check (
    mime_type is null
    or mime_type = any (array[
      'application/pdf',
      'image/jpeg',
      'image/png',
      'image/webp',
      'image/heic',
      'image/heif'
    ])
  );

alter table public.documents
  add constraint documents_storage_path_key unique (storage_path);

drop policy "documents_bucket_access" on storage.objects;

create policy "documents_bucket_access"
  on storage.objects for all
  to authenticated
  using (
    bucket_id = 'documents'
    and case
      when cardinality(storage.foldername(name)) >= 2
        and (storage.foldername(name))[1]
          ~ '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89aAbB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$'
      then public.has_account_access((storage.foldername(name))[1]::uuid)
      else false
    end
  )
  with check (
    bucket_id = 'documents'
    and case
      when cardinality(storage.foldername(name)) >= 2
        and (storage.foldername(name))[1]
          ~ '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89aAbB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$'
      then public.has_account_access((storage.foldername(name))[1]::uuid)
      else false
    end
  );

drop policy "item_photos_bucket_access" on storage.objects;

create policy "item_photos_bucket_access"
  on storage.objects for all
  to authenticated
  using (
    bucket_id = 'item-photos'
    and case
      when cardinality(storage.foldername(name)) >= 2
        and (storage.foldername(name))[1]
          ~ '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89aAbB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$'
      then public.has_account_access((storage.foldername(name))[1]::uuid)
      else false
    end
  )
  with check (
    bucket_id = 'item-photos'
    and case
      when cardinality(storage.foldername(name)) >= 2
        and (storage.foldername(name))[1]
          ~ '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89aAbB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$'
      then public.has_account_access((storage.foldername(name))[1]::uuid)
      else false
    end
  );
