alter table public.provider_profiles
  add column if not exists notify_booking_requests boolean not null default true,
  add column if not exists notify_booking_updates boolean not null default true,
  add column if not exists notify_messages boolean not null default true,
  add column if not exists notify_payments boolean not null default true,
  add column if not exists profile_visible boolean not null default true,
  add column if not exists marketplace_discoverable boolean not null default true,
  add column if not exists allow_customer_messages boolean not null default true,
  add column if not exists show_availability boolean not null default true;
