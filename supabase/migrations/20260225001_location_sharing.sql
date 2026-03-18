-- ============================================================
--  Migration 001 · Location Sharing
--  Safe to re-run: uses IF NOT EXISTS / OR REPLACE
-- ============================================================

ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS is_location_sharing BOOLEAN DEFAULT FALSE;

DROP FUNCTION IF EXISTS public.get_nearby_users(double precision, double precision, double precision, uuid);

CREATE OR REPLACE FUNCTION public.get_nearby_users(
  lat              DOUBLE PRECISION,
  long             DOUBLE PRECISION,
  radius           DOUBLE PRECISION DEFAULT 5000,
  current_user_id  UUID DEFAULT NULL
)
RETURNS TABLE (
  id                  UUID,
  username            TEXT,
  display_name        TEXT,
  avatar_url          TEXT,
  latitude            DOUBLE PRECISION,
  longitude           DOUBLE PRECISION,
  last_seen           TIMESTAMPTZ,
  is_online           BOOLEAN,
  is_location_sharing BOOLEAN,
  distance_meters     DOUBLE PRECISION
)
LANGUAGE sql STABLE AS $$
  SELECT
    p.id, p.username, p.display_name, p.avatar_url,
    p.latitude, p.longitude, p.last_seen, p.is_online,
    p.is_location_sharing,
    ST_Distance(
      p.last_known_location,
      ST_SetSRID(ST_MakePoint(long, lat), 4326)::GEOGRAPHY
    ) AS distance_meters
  FROM public.profiles p
  WHERE
    p.last_known_location IS NOT NULL
    AND p.is_location_sharing = TRUE
    AND (current_user_id IS NULL OR p.id <> current_user_id)
    AND ST_DWithin(
      p.last_known_location,
      ST_SetSRID(ST_MakePoint(long, lat), 4326)::GEOGRAPHY,
      radius
    )
  ORDER BY distance_meters ASC;
$$;
