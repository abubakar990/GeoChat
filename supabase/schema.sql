-- ============================================================
--  GeoMessage · Supabase + PostGIS Schema
--  Run this in your Supabase SQL Editor (Dashboard → SQL Editor)
-- ============================================================

-- 1. Enable the PostGIS extension
CREATE EXTENSION IF NOT EXISTS postgis;

-- ============================================================
-- 2. PROFILES TABLE
-- ============================================================
CREATE TABLE IF NOT EXISTS public.profiles (
  id            UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  username      TEXT UNIQUE NOT NULL,
  email         TEXT,
  display_name  TEXT,
  avatar_url    TEXT,
  -- Plain lat/lng columns for easy querying
  latitude      DOUBLE PRECISION,
  longitude     DOUBLE PRECISION,
  -- PostGIS geography column for ST_DWithin spatial queries
  last_known_location GEOGRAPHY(POINT, 4326),
  last_seen     TIMESTAMPTZ DEFAULT NOW(),
  is_online     BOOLEAN DEFAULT FALSE,
  -- Privacy: user can hide their location from everyone
  is_location_sharing BOOLEAN DEFAULT FALSE,
  created_at    TIMESTAMPTZ DEFAULT NOW()
);

-- Auto-update last_known_location whenever lat/lng change
CREATE OR REPLACE FUNCTION sync_location_point()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.latitude IS NOT NULL AND NEW.longitude IS NOT NULL THEN
    NEW.last_known_location := ST_SetSRID(
      ST_MakePoint(NEW.longitude, NEW.latitude), 4326
    )::GEOGRAPHY;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_sync_location ON public.profiles;
CREATE TRIGGER trg_sync_location
  BEFORE INSERT OR UPDATE OF latitude, longitude ON public.profiles
  FOR EACH ROW EXECUTE FUNCTION sync_location_point();

-- ============================================================
-- 3. CONVERSATIONS TABLE
-- ============================================================
CREATE TABLE IF NOT EXISTS public.conversations (
  id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  participant_ids  UUID[] NOT NULL,
  created_at       TIMESTAMPTZ DEFAULT NOW(),
  updated_at       TIMESTAMPTZ DEFAULT NOW()
);

-- Index for fast participant look-up
CREATE INDEX IF NOT EXISTS idx_conversations_participants
  ON public.conversations USING GIN(participant_ids);

-- ============================================================
-- 4. MESSAGES TABLE
-- ============================================================
CREATE TABLE IF NOT EXISTS public.messages (
  id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  conversation_id  UUID NOT NULL REFERENCES public.conversations(id) ON DELETE CASCADE,
  sender_id        UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  type             TEXT NOT NULL DEFAULT 'text'
                     CHECK (type IN ('text','image','location_share','system')),
  content          TEXT,           -- plain or AES-256 ciphertext
  media_url        TEXT,
  location_lat     DOUBLE PRECISION,
  location_lng     DOUBLE PRECISION,
  is_encrypted     BOOLEAN DEFAULT FALSE,
  is_read          BOOLEAN DEFAULT FALSE,
  created_at       TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_messages_conversation
  ON public.messages(conversation_id, created_at);

-- ============================================================
-- 5. RPC: get_nearby_users
--    Returns users within [radius] metres of (lat, long),
--    excluding the calling user. Distance is included so the
--    Flutter app can sort / display it directly.
-- ============================================================
CREATE OR REPLACE FUNCTION public.get_nearby_users(
  lat              DOUBLE PRECISION,
  long             DOUBLE PRECISION,
  radius           DOUBLE PRECISION DEFAULT 5000,
  current_user_id  UUID DEFAULT NULL
)
RETURNS TABLE (
  id               UUID,
  username         TEXT,
  display_name     TEXT,
  avatar_url       TEXT,
  latitude         DOUBLE PRECISION,
  longitude        DOUBLE PRECISION,
  last_seen        TIMESTAMPTZ,
  is_online        BOOLEAN,
  is_location_sharing BOOLEAN,
  distance_meters  DOUBLE PRECISION
)
LANGUAGE sql STABLE AS $$
  SELECT
    p.id,
    p.username,
    p.display_name,
    p.avatar_url,
    p.latitude,
    p.longitude,
    p.last_seen,
    p.is_online,
    p.is_location_sharing,
    ST_Distance(
      p.last_known_location,
      ST_SetSRID(ST_MakePoint(long, lat), 4326)::GEOGRAPHY
    ) AS distance_meters
  FROM public.profiles p
  WHERE
    p.last_known_location IS NOT NULL
    -- Only show users who have opted IN to location sharing
    AND p.is_location_sharing = TRUE
    AND (current_user_id IS NULL OR p.id <> current_user_id)
    AND ST_DWithin(
      p.last_known_location,
      ST_SetSRID(ST_MakePoint(long, lat), 4326)::GEOGRAPHY,
      radius
    )
  ORDER BY distance_meters ASC;
$$;

-- ============================================================
-- 6. ROW LEVEL SECURITY (RLS)
-- ============================================================

-- Profiles
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

CREATE POLICY "profiles_select_authenticated"
  ON public.profiles FOR SELECT
  USING (auth.role() = 'authenticated');

CREATE POLICY "profiles_insert_own"
  ON public.profiles FOR INSERT
  WITH CHECK (auth.uid() = id);

CREATE POLICY "profiles_update_own"
  ON public.profiles FOR UPDATE
  USING (auth.uid() = id);

-- Conversations
ALTER TABLE public.conversations ENABLE ROW LEVEL SECURITY;

CREATE POLICY "conversations_select_participant"
  ON public.conversations FOR SELECT
  USING (auth.uid() = ANY(participant_ids));

CREATE POLICY "conversations_insert_authenticated"
  ON public.conversations FOR INSERT
  WITH CHECK (auth.uid() = ANY(participant_ids));

-- Messages
ALTER TABLE public.messages ENABLE ROW LEVEL SECURITY;

CREATE POLICY "messages_select_participant"
  ON public.messages FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.conversations c
      WHERE c.id = conversation_id
        AND auth.uid() = ANY(c.participant_ids)
    )
  );

CREATE POLICY "messages_insert_own"
  ON public.messages FOR INSERT
  WITH CHECK (auth.uid() = sender_id);

-- ============================================================
-- 7. REALTIME – enable publications
-- ============================================================
-- Enable realtime for the messages table (Postgres Changes)
ALTER PUBLICATION supabase_realtime ADD TABLE public.messages;

-- ============================================================
-- 8. STORAGE BUCKETS
--    Create these in Supabase Dashboard → Storage, OR via SQL:
-- ============================================================
-- INSERT INTO storage.buckets (id, name, public)
--   VALUES ('avatars', 'avatars', true)
--   ON CONFLICT DO NOTHING;

-- INSERT INTO storage.buckets (id, name, public)
--   VALUES ('message-media', 'message-media', false)
--   ON CONFLICT DO NOTHING;
