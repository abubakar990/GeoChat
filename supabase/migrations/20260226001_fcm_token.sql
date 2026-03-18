-- ============================================================
-- Add fcm_token column to profiles table
-- Run this in the Supabase SQL Editor
-- ============================================================

alter table public.profiles
  add column if not exists fcm_token text;

-- Index for fast lookups (optional — tokens are unique per device)
create index if not exists profiles_fcm_token_idx
  on public.profiles (fcm_token)
  where fcm_token is not null;
