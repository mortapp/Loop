-- Storage: a single "documents" bucket, partitioned by account_id as the
-- first path segment (e.g. "<account_id>/<document_id>/<file_name>"), so
-- the same has_account_access() rule that guards the documents table also
-- guards the underlying files.

insert into storage.buckets (id, name, public)
values ('documents', 'documents', false)
on conflict (id) do nothing;

create policy "documents_bucket_access"
  on storage.objects for all
  to authenticated
  using (
    bucket_id = 'documents'
    and public.has_account_access((storage.foldername(name))[1]::uuid)
  )
  with check (
    bucket_id = 'documents'
    and public.has_account_access((storage.foldername(name))[1]::uuid)
  );
