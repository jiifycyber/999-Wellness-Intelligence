create table if not exists public.community_posts (
  id uuid primary key default gen_random_uuid(),
  author_id uuid not null references auth.users(id) on delete cascade,
  author_name text not null,
  author_role text not null check (author_role in ('customer', 'provider')),
  author_photo_url text,
  body text not null default '',
  media_path text,
  media_type text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint community_posts_content_check
    check (
      length(trim(body)) > 0
      or media_path is not null
    )
);

create index if not exists community_posts_created_at_idx
  on public.community_posts (created_at desc);

create index if not exists community_posts_author_id_idx
  on public.community_posts (author_id);

create table if not exists public.community_comments (
  id uuid primary key default gen_random_uuid(),
  post_id uuid not null
    references public.community_posts(id)
    on delete cascade,
  author_id uuid not null
    references auth.users(id)
    on delete cascade,
  author_name text not null,
  author_role text not null
    check (author_role in ('customer', 'provider')),
  body text not null
    check (length(trim(body)) > 0),
  created_at timestamptz not null default now()
);

create index if not exists community_comments_post_id_idx
  on public.community_comments (post_id, created_at);

create table if not exists public.community_likes (
  post_id uuid not null
    references public.community_posts(id)
    on delete cascade,
  user_id uuid not null
    references auth.users(id)
    on delete cascade,
  created_at timestamptz not null default now(),
  primary key (post_id, user_id)
);

create table if not exists public.community_follows (
  follower_id uuid not null
    references auth.users(id)
    on delete cascade,
  following_id uuid not null
    references auth.users(id)
    on delete cascade,
  created_at timestamptz not null default now(),
  primary key (follower_id, following_id),
  constraint community_follows_not_self
    check (follower_id <> following_id)
);

create index if not exists community_follows_following_idx
  on public.community_follows (following_id);

create table if not exists public.community_live_sessions (
  id uuid primary key default gen_random_uuid(),
  host_id uuid not null
    references auth.users(id)
    on delete cascade,
  host_name text not null,
  host_role text not null
    check (host_role in ('customer', 'provider')),
  host_photo_url text,
  title text not null default 'Live on 999 Wellness',
  stream_provider text not null default 'unconfigured',
  room_name text,
  status text not null default 'setup'
    check (status in ('setup', 'live', 'ended')),
  viewer_count integer not null default 0,
  started_at timestamptz,
  ended_at timestamptz,
  created_at timestamptz not null default now()
);

create index if not exists community_live_status_idx
  on public.community_live_sessions (status, created_at desc);

create table if not exists public.community_live_comments (
  id uuid primary key default gen_random_uuid(),
  live_session_id uuid not null
    references public.community_live_sessions(id)
    on delete cascade,
  author_id uuid not null
    references auth.users(id)
    on delete cascade,
  author_name text not null,
  body text not null
    check (length(trim(body)) > 0),
  created_at timestamptz not null default now()
);

alter table public.community_posts enable row level security;
alter table public.community_comments enable row level security;
alter table public.community_likes enable row level security;
alter table public.community_follows enable row level security;
alter table public.community_live_sessions enable row level security;
alter table public.community_live_comments enable row level security;

drop policy if exists "community_posts_read" on public.community_posts;
drop policy if exists "community_posts_insert" on public.community_posts;
drop policy if exists "community_posts_update" on public.community_posts;
drop policy if exists "community_posts_delete" on public.community_posts;

create policy "community_posts_read"
on public.community_posts
for select
to authenticated
using (true);

create policy "community_posts_insert"
on public.community_posts
for insert
to authenticated
with check (author_id = auth.uid());

create policy "community_posts_update"
on public.community_posts
for update
to authenticated
using (author_id = auth.uid())
with check (author_id = auth.uid());

create policy "community_posts_delete"
on public.community_posts
for delete
to authenticated
using (author_id = auth.uid());

drop policy if exists "community_comments_read" on public.community_comments;
drop policy if exists "community_comments_insert" on public.community_comments;
drop policy if exists "community_comments_delete" on public.community_comments;

create policy "community_comments_read"
on public.community_comments
for select
to authenticated
using (true);

create policy "community_comments_insert"
on public.community_comments
for insert
to authenticated
with check (author_id = auth.uid());

create policy "community_comments_delete"
on public.community_comments
for delete
to authenticated
using (author_id = auth.uid());

drop policy if exists "community_likes_read" on public.community_likes;
drop policy if exists "community_likes_insert" on public.community_likes;
drop policy if exists "community_likes_delete" on public.community_likes;

create policy "community_likes_read"
on public.community_likes
for select
to authenticated
using (true);

create policy "community_likes_insert"
on public.community_likes
for insert
to authenticated
with check (user_id = auth.uid());

create policy "community_likes_delete"
on public.community_likes
for delete
to authenticated
using (user_id = auth.uid());

drop policy if exists "community_follows_read" on public.community_follows;
drop policy if exists "community_follows_insert" on public.community_follows;
drop policy if exists "community_follows_delete" on public.community_follows;

create policy "community_follows_read"
on public.community_follows
for select
to authenticated
using (true);

create policy "community_follows_insert"
on public.community_follows
for insert
to authenticated
with check (follower_id = auth.uid());

create policy "community_follows_delete"
on public.community_follows
for delete
to authenticated
using (follower_id = auth.uid());

drop policy if exists "community_live_read" on public.community_live_sessions;
drop policy if exists "community_live_insert" on public.community_live_sessions;
drop policy if exists "community_live_update" on public.community_live_sessions;
drop policy if exists "community_live_delete" on public.community_live_sessions;

create policy "community_live_read"
on public.community_live_sessions
for select
to authenticated
using (true);

create policy "community_live_insert"
on public.community_live_sessions
for insert
to authenticated
with check (host_id = auth.uid());

create policy "community_live_update"
on public.community_live_sessions
for update
to authenticated
using (host_id = auth.uid())
with check (host_id = auth.uid());

create policy "community_live_delete"
on public.community_live_sessions
for delete
to authenticated
using (host_id = auth.uid());

drop policy if exists "community_live_comments_read"
  on public.community_live_comments;
drop policy if exists "community_live_comments_insert"
  on public.community_live_comments;
drop policy if exists "community_live_comments_delete"
  on public.community_live_comments;

create policy "community_live_comments_read"
on public.community_live_comments
for select
to authenticated
using (true);

create policy "community_live_comments_insert"
on public.community_live_comments
for insert
to authenticated
with check (author_id = auth.uid());

create policy "community_live_comments_delete"
on public.community_live_comments
for delete
to authenticated
using (author_id = auth.uid());

insert into storage.buckets (
  id,
  name,
  public,
  file_size_limit,
  allowed_mime_types
)
values (
  'feed-media',
  'feed-media',
  false,
  15728640,
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
  file_size_limit = 15728640,
  allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "feed_media_read" on storage.objects;
drop policy if exists "feed_media_insert" on storage.objects;
drop policy if exists "feed_media_delete" on storage.objects;

create policy "feed_media_read"
on storage.objects
for select
to authenticated
using (bucket_id = 'feed-media');

create policy "feed_media_insert"
on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'feed-media'
  and (storage.foldername(name))[1] = auth.uid()::text
);

create policy "feed_media_delete"
on storage.objects
for delete
to authenticated
using (
  bucket_id = 'feed-media'
  and (storage.foldername(name))[1] = auth.uid()::text
);
