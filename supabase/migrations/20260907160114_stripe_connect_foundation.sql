-- ============================================================
-- 999 Wellness Intelligence
-- Stripe Connect foundation
-- ============================================================

alter table public.provider_profiles
  add column if not exists stripe_account_id text,
  add column if not exists stripe_details_submitted boolean not null default false,
  add column if not exists stripe_charges_enabled boolean not null default false,
  add column if not exists stripe_payouts_enabled boolean not null default false,
  add column if not exists stripe_onboarding_complete boolean not null default false;

create unique index if not exists provider_profiles_stripe_account_id_uidx
  on public.provider_profiles (stripe_account_id)
  where stripe_account_id is not null;

alter table public.bookings
  add column if not exists stripe_payment_intent_id text,
  add column if not exists stripe_charge_id text,
  add column if not exists stripe_transfer_id text,
  add column if not exists currency text not null default 'usd',
  add column if not exists platform_fee_amount numeric(12,2),
  add column if not exists provider_payout_amount numeric(12,2),
  add column if not exists payment_completed_at timestamptz,
  add column if not exists payment_failed_at timestamptz,
  add column if not exists refunded_at timestamptz;

create unique index if not exists bookings_stripe_payment_intent_id_uidx
  on public.bookings (stripe_payment_intent_id)
  where stripe_payment_intent_id is not null;

create index if not exists bookings_payment_status_idx
  on public.bookings (payment_status);

create index if not exists bookings_provider_id_idx
  on public.bookings (provider_id);
