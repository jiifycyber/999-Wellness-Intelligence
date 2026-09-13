alter table public.community_posts
drop constraint if exists community_posts_content_check;

alter table public.community_posts
add constraint community_posts_content_check
check (
  length(trim(body)) > 0
  or media_path is not null
  or music_track_id is not null
);
