create table if not exists public.community_member_profiles (
  user_id uuid primary key
    references auth.users(id)
    on delete cascade,
  display_name text not null default '999 Member',
  role text not null default 'customer'
    check (role in ('customer', 'provider')),
  photo_url text,
  photo_path text,
  bio text not null default '',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists community_member_profiles_role_idx
  on public.community_member_profiles (role);

alter table public.community_member_profiles
  enable row level security;

drop policy if exists "community_member_profiles_read"
  on public.community_member_profiles;

drop policy if exists "community_member_profiles_insert"
  on public.community_member_profiles;

drop policy if exists "community_member_profiles_update"
  on public.community_member_profiles;

create policy "community_member_profiles_read"
on public.community_member_profiles
for select
to authenticated
using (true);

create policy "community_member_profiles_insert"
on public.community_member_profiles
for insert
to authenticated
with check (user_id = auth.uid());

create policy "community_member_profiles_update"
on public.community_member_profiles
for update
to authenticated
using (user_id = auth.uid())
with check (user_id = auth.uid());

insert into storage.buckets (
  id,
  name,
  public,
  file_size_limit,
  allowed_mime_types
)
values (
  'community-profile-media',
  'community-profile-media',
  false,
  10485760,
  array[
    'image/jpeg',
    'image/png',
    'image/webp',
    'image/heic',
    'image/heif'
  ]
)
on conflict (id) do update set
  public = false,
  file_size_limit = 10485760,
  allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "community_profile_media_read"
  on storage.objects;

drop policy if exists "community_profile_media_insert"
  on storage.objects;

drop policy if exists "community_profile_media_update"
  on storage.objects;

drop policy if exists "community_profile_media_delete"
  on storage.objects;

create policy "community_profile_media_read"
on storage.objects
for select
to authenticated
using (
  bucket_id = 'community-profile-media'
);

create policy "community_profile_media_insert"
on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'community-profile-media'
  and (storage.foldername(name))[1] = auth.uid()::text
);

create policy "community_profile_media_update"
on storage.objects
for update
to authenticated
using (
  bucket_id = 'community-profile-media'
  and (storage.foldername(name))[1] = auth.uid()::text
)
with check (
  bucket_id = 'community-profile-media'
  and (storage.foldername(name))[1] = auth.uid()::text
);

create policy "community_profile_media_delete"
on storage.objects
for delete
to authenticated
using (
  bucket_id = 'community-profile-media'
  and (storage.foldername(name))[1] = auth.uid()::text
);
