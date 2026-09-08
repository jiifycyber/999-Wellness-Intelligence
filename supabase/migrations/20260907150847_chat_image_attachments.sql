alter table public.messages
  add column if not exists attachment_path text,
  add column if not exists attachment_name text,
  add column if not exists attachment_type text;

insert into storage.buckets (
  id,
  name,
  public,
  file_size_limit,
  allowed_mime_types
)
values (
  'chat-media',
  'chat-media',
  false,
  10485760,
  array[
    'image/jpeg',
    'image/png',
    'image/webp',
    'image/gif',
    'image/heic',
    'image/heif'
  ]
)
on conflict (id) do update set
  public = false,
  file_size_limit = 10485760,
  allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "chat_media_insert" on storage.objects;
drop policy if exists "chat_media_select" on storage.objects;
drop policy if exists "chat_media_delete" on storage.objects;

create policy "chat_media_insert"
on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'chat-media'
  and (storage.foldername(name))[1] = auth.uid()::text
);

create policy "chat_media_select"
on storage.objects
for select
to authenticated
using (
  bucket_id = 'chat-media'
  and (
    (storage.foldername(name))[1] = auth.uid()::text
    or
    (storage.foldername(name))[2] = auth.uid()::text
  )
);

create policy "chat_media_delete"
on storage.objects
for delete
to authenticated
using (
  bucket_id = 'chat-media'
  and (storage.foldername(name))[1] = auth.uid()::text
);
