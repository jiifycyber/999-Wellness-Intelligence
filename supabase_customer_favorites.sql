create table if not exists public.customer_favorites (
  id uuid primary key default gen_random_uuid(),
  customer_id uuid not null references auth.users(id) on delete cascade,
  provider_id uuid not null references public.provider_profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  unique(customer_id, provider_id)
);

alter table public.customer_favorites enable row level security;

drop policy if exists "Customers can view their own favorites"
on public.customer_favorites;

create policy "Customers can view their own favorites"
on public.customer_favorites
for select
using (auth.uid() = customer_id);

drop policy if exists "Customers can add their own favorites"
on public.customer_favorites;

create policy "Customers can add their own favorites"
on public.customer_favorites
for insert
with check (auth.uid() = customer_id);

drop policy if exists "Customers can remove their own favorites"
on public.customer_favorites;

create policy "Customers can remove their own favorites"
on public.customer_favorites
for delete
using (auth.uid() = customer_id);

create index if not exists customer_favorites_customer_id_idx
on public.customer_favorites(customer_id);

create index if not exists customer_favorites_provider_id_idx
on public.customer_favorites(provider_id);
