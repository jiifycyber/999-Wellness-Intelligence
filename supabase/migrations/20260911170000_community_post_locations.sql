alter table public.community_posts
add column if not exists location_name text;

alter table public.community_posts
add column if not exists location_subtitle text;

alter table public.community_posts
add column if not exists location_lat double precision;

alter table public.community_posts
add column if not exists location_lng double precision;
