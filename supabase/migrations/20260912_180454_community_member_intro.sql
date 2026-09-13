alter table public.community_member_profiles
add column if not exists member_intro text
default '999 WELLNESS MEMBER';

update public.community_member_profiles
set member_intro = '999 WELLNESS MEMBER'
where member_intro is null
   or btrim(member_intro) = '';

alter table public.community_member_profiles
drop constraint if exists community_member_profiles_member_intro_length;

alter table public.community_member_profiles
add constraint community_member_profiles_member_intro_length
check (char_length(member_intro) <= 100);
