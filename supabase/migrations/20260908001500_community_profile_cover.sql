alter table public.community_member_profiles
  add column if not exists cover_url text,
  add column if not exists cover_path text;
