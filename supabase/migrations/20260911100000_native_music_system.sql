create extension if not exists pgcrypto;

create table if not exists public.music_tracks (
  id uuid primary key default gen_random_uuid(),
  artist_name text not null,
  title text not null,
  featured_artist text,
  album_name text,
  release_type text not null default 'single',
  track_number integer,
  duration_seconds integer,
  audio_path text,
  artwork_path text,
  spotify_url text,
  distrokid_url text,
  explicit boolean not null default false,
  active boolean not null default false,
  featured boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.music_tracks enable row level security;

drop policy if exists "Public can read active music tracks"
on public.music_tracks;

create policy "Public can read active music tracks"
on public.music_tracks
for select
using (active = true);

drop policy if exists "Authenticated users can read music tracks"
on public.music_tracks;

create policy "Authenticated users can read music tracks"
on public.music_tracks
for select
to authenticated
using (true);

insert into storage.buckets (
  id,
  name,
  public,
  file_size_limit,
  allowed_mime_types
)
values (
  'music-audio',
  'music-audio',
  true,
  104857600,
  array[
    'audio/mpeg',
    'audio/mp3',
    'audio/wav',
    'audio/x-wav',
    'audio/mp4',
    'audio/aac'
  ]
)
on conflict (id) do update
set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

insert into storage.buckets (
  id,
  name,
  public,
  file_size_limit,
  allowed_mime_types
)
values (
  'music-artwork',
  'music-artwork',
  true,
  15728640,
  array[
    'image/jpeg',
    'image/png',
    'image/webp'
  ]
)
on conflict (id) do update
set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "Public can read music audio"
on storage.objects;

create policy "Public can read music audio"
on storage.objects
for select
using (bucket_id = 'music-audio');

drop policy if exists "Public can read music artwork"
on storage.objects;

create policy "Public can read music artwork"
on storage.objects
for select
using (bucket_id = 'music-artwork');

alter table public.community_posts
  add column if not exists music_track_id uuid
    references public.music_tracks(id)
    on delete set null;

alter table public.community_posts
  add column if not exists music_title text;

alter table public.community_posts
  add column if not exists music_artist text;

alter table public.community_posts
  add column if not exists music_featured_artist text;

alter table public.community_posts
  add column if not exists music_album text;

alter table public.community_posts
  add column if not exists music_artwork_path text;

alter table public.community_posts
  add column if not exists music_audio_path text;

alter table public.community_posts
  add column if not exists music_spotify_url text;

insert into public.music_tracks (
  artist_name,
  title,
  featured_artist,
  album_name,
  release_type,
  duration_seconds,
  audio_path,
  artwork_path,
  distrokid_url,
  explicit,
  active,
  featured
)
select
  'Duke Da Boss X',
  'No Love',
  'Noor X',
  'No Love',
  'single',
  316,
  'duke-da-boss-x/no-love/no-love.mp3',
  'duke-da-boss-x/no-love/cover.jpg',
  'https://distrokid.com/hyperfollow/dukedabossx/no-love/',
  true,
  false,
  true
where not exists (
  select 1
  from public.music_tracks
  where lower(artist_name) = lower('Duke Da Boss X')
    and lower(title) = lower('No Love')
);

create index if not exists music_tracks_active_idx
on public.music_tracks(active);

create index if not exists music_tracks_artist_idx
on public.music_tracks(lower(artist_name));

create index if not exists community_posts_music_track_idx
on public.community_posts(music_track_id);
