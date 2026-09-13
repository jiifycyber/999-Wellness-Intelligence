alter table public.community_posts
add column if not exists tagged_people jsonb not null default '[]'::jsonb;

alter table public.community_posts
add column if not exists location_name text;

alter table public.community_posts
add column if not exists feeling_activity text;
