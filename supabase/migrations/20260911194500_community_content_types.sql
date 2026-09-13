alter table public.community_posts
add column if not exists content_type text not null default 'post';

alter table public.community_posts
add column if not exists expires_at timestamptz;

alter table public.community_posts
drop constraint if exists community_posts_content_type_check;

alter table public.community_posts
add constraint community_posts_content_type_check
check (
  content_type in (
    'post',
    'story',
    'reel',
    'note'
  )
);

create index if not exists community_posts_content_type_idx
on public.community_posts (content_type);

create index if not exists community_posts_expires_at_idx
on public.community_posts (expires_at);

update public.community_posts
set content_type = 'post'
where content_type is null
   or trim(content_type) = '';
