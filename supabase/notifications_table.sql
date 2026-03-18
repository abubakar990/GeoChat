-- ============================================================
-- Notifications table for GeoChat
-- Run this in the Supabase SQL Editor
-- ============================================================

create table if not exists public.notifications (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references public.profiles(id) on delete cascade,
  type        text not null,           -- 'new_message' | 'friend_request' | 'friend_accepted' | 'wave' | 'nearby_user'
  title       text not null,
  body        text not null default '',
  is_read     boolean not null default false,
  reference_id text,                   -- conversationId, userId, etc.
  actor_name  text,
  actor_avatar text,
  created_at  timestamptz not null default now()
);

-- Index for fast per-user queries
create index if not exists notifications_user_id_idx
  on public.notifications (user_id, created_at desc);

-- Enable Row Level Security
alter table public.notifications enable row level security;

-- Users can only see their own notifications
create policy "Users see own notifications"
  on public.notifications for select
  using (auth.uid() = user_id);

-- Any authenticated user can insert (to notify others)
create policy "Authenticated users can insert notifications"
  on public.notifications for insert
  with check (auth.role() = 'authenticated');

-- Users can update (mark read) only their own notifications
create policy "Users can mark own notifications read"
  on public.notifications for update
  using (auth.uid() = user_id);

-- Users can delete their own notifications
create policy "Users can delete own notifications"
  on public.notifications for delete
  using (auth.uid() = user_id);

-- Enable realtime for the notifications table
alter publication supabase_realtime add table public.notifications;
