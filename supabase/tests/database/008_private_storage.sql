-- pgTAP coverage for private bucket limits, path-scoped RLS, and document
-- metadata integrity. All fixtures are synthetic and rolled back.

create extension if not exists pgtap;

begin;

select plan(18);

do $$
declare
  v_instance_id uuid := '00000000-0000-0000-0000-000000000000';
begin
  insert into auth.users (
    instance_id, id, aud, role, email, encrypted_password,
    email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
    created_at, updated_at
  ) values
    (v_instance_id, '11111111-1111-4111-8111-111111111111', 'authenticated', 'authenticated',
     'storage-a@test.local', crypt('password123', gen_salt('bf')), now(), '{}', '{}', now(), now()),
    (v_instance_id, '22222222-2222-4222-8222-222222222222', 'authenticated', 'authenticated',
     'storage-b@test.local', crypt('password123', gen_salt('bf')), now(), '{}', '{}', now(), now());

  update public.accounts
  set id = '33333333-3333-4333-8333-333333333333'
  where owner_profile_id = '11111111-1111-4111-8111-111111111111';

  update public.accounts
  set id = '44444444-4444-4444-8444-444444444444'
  where owner_profile_id = '22222222-2222-4222-8222-222222222222';
end $$;

create or replace function pg_temp.authenticate_as(user_id uuid) returns void as $$
begin
  execute 'set local role authenticated';
  perform set_config(
    'request.jwt.claims',
    json_build_object('sub', user_id, 'role', 'authenticated')::text,
    true
  );
end;
$$ language plpgsql;

select is(
  (select public from storage.buckets where id = 'documents'),
  false,
  'documents bucket is private'
);

select is(
  (select file_size_limit from storage.buckets where id = 'documents'),
  12582912::bigint,
  'documents bucket enforces a 12 MiB limit'
);

select is(
  (select allowed_mime_types from storage.buckets where id = 'documents'),
  array[
    'application/pdf', 'image/jpeg', 'image/png', 'image/webp',
    'image/heic', 'image/heif'
  ]::text[],
  'documents bucket accepts only supported document/image types'
);

select is(
  (select file_size_limit from storage.buckets where id = 'item-photos'),
  8388608::bigint,
  'item photos retain the 8 MiB limit'
);

select pg_temp.authenticate_as('11111111-1111-4111-8111-111111111111');

select lives_ok(
  $$ insert into storage.objects (bucket_id, name)
     values ('documents', '33333333-3333-4333-8333-333333333333/document-a/receipt.pdf') $$,
  'an account owner can create an object under their own documents path'
);

select throws_ok(
  $$ insert into storage.objects (bucket_id, name)
     values ('documents', 'not-a-uuid/document-b/receipt.pdf') $$,
  '42501', null,
  'a malformed account path fails closed instead of throwing a UUID cast error'
);

select throws_ok(
  $$ insert into storage.objects (bucket_id, name)
     values ('documents', '44444444-4444-4444-8444-444444444444/document-c/receipt.pdf') $$,
  '42501', null,
  'an account owner cannot create an object under another account path'
);

select lives_ok(
  $$ insert into storage.objects (bucket_id, name)
     values ('item-photos', '33333333-3333-4333-8333-333333333333/item-a/photo.jpg') $$,
  'an account owner can create an item photo under their own path'
);

select throws_ok(
  $$ insert into storage.objects (bucket_id, name)
     values ('item-photos', 'bad/item-b/photo.jpg') $$,
  '42501', null,
  'item photo malformed paths also fail closed'
);

select pg_temp.authenticate_as('22222222-2222-4222-8222-222222222222');

select is(
  (select count(*)::int from storage.objects
   where bucket_id = 'documents'
     and name = '33333333-3333-4333-8333-333333333333/document-a/receipt.pdf'),
  0,
  'another account cannot read the object metadata'
);

select throws_ok(
  $$ delete from storage.objects
     where bucket_id = 'documents'
       and name = '33333333-3333-4333-8333-333333333333/document-a/receipt.pdf' $$,
  '42501', null,
  'direct SQL cannot bypass the Storage object API for deletion'
);

select pg_temp.authenticate_as('11111111-1111-4111-8111-111111111111');

select is(
  (select count(*)::int from storage.objects
   where bucket_id = 'documents'
     and name = '33333333-3333-4333-8333-333333333333/document-a/receipt.pdf'),
  1,
  'the owner still sees the object after another account tried to delete it'
);

select throws_ok(
  $$ insert into public.documents (account_id, storage_path, file_name)
     values (
       '33333333-3333-4333-8333-333333333333',
       '44444444-4444-4444-8444-444444444444/document/receipt.pdf',
       'receipt.pdf'
     ) $$,
  '23514', null,
  'document metadata path must begin with its own account ID'
);

select lives_ok(
  $$ insert into public.documents (account_id, storage_path, file_name, mime_type, size_bytes)
     values (
       '33333333-3333-4333-8333-333333333333',
       '33333333-3333-4333-8333-333333333333/document/receipt.pdf',
       'receipt.pdf', 'application/pdf', 1024
     ) $$,
  'valid document metadata remains insertable'
);

select throws_ok(
  $$ insert into public.documents (account_id, storage_path, file_name)
     values (
       '33333333-3333-4333-8333-333333333333',
       '33333333-3333-4333-8333-333333333333/document/receipt.pdf',
       'duplicate.pdf'
     ) $$,
  '23505', null,
  'one storage object path cannot back duplicate document rows'
);

select throws_ok(
  $$ insert into public.documents (account_id, storage_path, file_name, size_bytes)
     values (
       '33333333-3333-4333-8333-333333333333',
       '33333333-3333-4333-8333-333333333333/document/large.pdf',
       'large.pdf', 12582913
     ) $$,
  '23514', null,
  'document metadata rejects a size above the bucket limit'
);

select throws_ok(
  $$ insert into public.documents (account_id, storage_path, file_name, mime_type)
     values (
       '33333333-3333-4333-8333-333333333333',
       '33333333-3333-4333-8333-333333333333/document/program.exe',
       'program.exe', 'application/octet-stream'
     ) $$,
  '23514', null,
  'document metadata rejects unsupported MIME types'
);

select throws_ok(
  $$ insert into public.documents (account_id, storage_path, file_name)
     values (
       '33333333-3333-4333-8333-333333333333',
       '33333333-3333-4333-8333-333333333333/document/empty',
       ''
     ) $$,
  '23514', null,
  'document metadata rejects an empty file name'
);

select * from finish();

rollback;
