-- ============================================================
-- 999 WELLNESS INTELLIGENCE
-- Provider schedule and availability system
-- ============================================================

create table if not exists public.provider_weekly_availability (
  id uuid primary key default gen_random_uuid(),
  provider_id uuid not null references auth.users(id) on delete cascade,
  day_of_week integer not null check (day_of_week between 1 and 7),
  enabled boolean not null default true,
  start_time time without time zone not null default '09:00',
  end_time time without time zone not null default '17:00',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint provider_weekly_availability_provider_day_unique
    unique (provider_id, day_of_week),
  constraint provider_weekly_availability_time_check
    check (end_time > start_time)
);

create table if not exists public.provider_blocked_times (
  id uuid primary key default gen_random_uuid(),
  provider_id uuid not null references auth.users(id) on delete cascade,
  start_at timestamptz not null,
  end_at timestamptz not null,
  reason text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint provider_blocked_times_range_check
    check (end_at > start_at)
);

create index if not exists provider_weekly_availability_provider_idx
  on public.provider_weekly_availability(provider_id);

create index if not exists provider_blocked_times_provider_idx
  on public.provider_blocked_times(provider_id);

create index if not exists provider_blocked_times_start_idx
  on public.provider_blocked_times(start_at);

alter table public.provider_weekly_availability enable row level security;
alter table public.provider_blocked_times enable row level security;

drop policy if exists provider_weekly_select_own
  on public.provider_weekly_availability;

create policy provider_weekly_select_own
  on public.provider_weekly_availability
  for select
  using (auth.uid() = provider_id);

drop policy if exists provider_weekly_insert_own
  on public.provider_weekly_availability;

create policy provider_weekly_insert_own
  on public.provider_weekly_availability
  for insert
  with check (auth.uid() = provider_id);

drop policy if exists provider_weekly_update_own
  on public.provider_weekly_availability;

create policy provider_weekly_update_own
  on public.provider_weekly_availability
  for update
  using (auth.uid() = provider_id)
  with check (auth.uid() = provider_id);

drop policy if exists provider_weekly_delete_own
  on public.provider_weekly_availability;

create policy provider_weekly_delete_own
  on public.provider_weekly_availability
  for delete
  using (auth.uid() = provider_id);

drop policy if exists provider_blocked_select_own
  on public.provider_blocked_times;

create policy provider_blocked_select_own
  on public.provider_blocked_times
  for select
  using (auth.uid() = provider_id);

drop policy if exists provider_blocked_insert_own
  on public.provider_blocked_times;

create policy provider_blocked_insert_own
  on public.provider_blocked_times
  for insert
  with check (auth.uid() = provider_id);

drop policy if exists provider_blocked_update_own
  on public.provider_blocked_times;

create policy provider_blocked_update_own
  on public.provider_blocked_times
  for update
  using (auth.uid() = provider_id)
  with check (auth.uid() = provider_id);

drop policy if exists provider_blocked_delete_own
  on public.provider_blocked_times;

create policy provider_blocked_delete_own
  on public.provider_blocked_times
  for delete
  using (auth.uid() = provider_id);

insert into public.provider_weekly_availability (
  provider_id,
  day_of_week,
  enabled,
  start_time,
  end_time
)
select
  p.id,
  d.day_of_week,
  case when d.day_of_week between 1 and 5 then true else false end,
  '09:00'::time,
  '17:00'::time
from public.provider_profiles p
cross join (
  values (1), (2), (3), (4), (5), (6), (7)
) as d(day_of_week)
on conflict (provider_id, day_of_week) do nothing;
