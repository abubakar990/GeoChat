-- ============================================================
--  GeoMessage · Migration: Friend System + Account Numbers
--  Run this in Supabase SQL Editor
-- ============================================================

-- ── 1. Unique account number generator ──────────────────────────────────────
CREATE OR REPLACE FUNCTION generate_account_number()
RETURNS TEXT LANGUAGE plpgsql AS $$
DECLARE
  num TEXT;
BEGIN
  LOOP
    -- Format: GEO-XXXXXXXX (8 uppercase hex chars)
    num := 'GEO-' || upper(substring(encode(gen_random_bytes(4), 'hex'), 1, 8));
    EXIT WHEN NOT EXISTS (
      SELECT 1 FROM public.profiles WHERE account_number = num
    );
  END LOOP;
  RETURN num;
END;
$$;

-- ── 2. Add account_number column to profiles ─────────────────────────────────
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS account_number TEXT UNIQUE DEFAULT NULL;

-- Back-fill existing rows
UPDATE public.profiles
  SET account_number = generate_account_number()
  WHERE account_number IS NULL;

-- ── 3. Trigger: auto-assign account_number on every INSERT ───────────────────
CREATE OR REPLACE FUNCTION trg_fn_set_account_number()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  IF NEW.account_number IS NULL THEN
    NEW.account_number := generate_account_number();
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_set_account_number ON public.profiles;
CREATE TRIGGER trg_set_account_number
  BEFORE INSERT ON public.profiles
  FOR EACH ROW EXECUTE FUNCTION trg_fn_set_account_number();

-- ── 4. Friend requests table ─────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.friend_requests (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  sender_id   UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  receiver_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  status      TEXT NOT NULL DEFAULT 'pending'
                CHECK (status IN ('pending', 'accepted', 'rejected')),
  created_at  TIMESTAMPTZ DEFAULT NOW(),
  updated_at  TIMESTAMPTZ DEFAULT NOW(),
  -- Prevent duplicate requests in either direction
  UNIQUE (sender_id, receiver_id)
);

CREATE INDEX IF NOT EXISTS idx_fr_receiver
  ON public.friend_requests(receiver_id, status);
CREATE INDEX IF NOT EXISTS idx_fr_sender
  ON public.friend_requests(sender_id, status);

-- ── 5. RLS for friend_requests ───────────────────────────────────────────────
ALTER TABLE public.friend_requests ENABLE ROW LEVEL SECURITY;

-- Sender and receiver can see the row
CREATE POLICY "fr_select_participant"
  ON public.friend_requests FOR SELECT
  USING (auth.uid() = sender_id OR auth.uid() = receiver_id);

-- Only sender can create a request
CREATE POLICY "fr_insert_sender"
  ON public.friend_requests FOR INSERT
  WITH CHECK (auth.uid() = sender_id);

-- Only receiver can accept/reject (UPDATE status)
CREATE POLICY "fr_update_receiver"
  ON public.friend_requests FOR UPDATE
  USING (auth.uid() = receiver_id);

-- ── 6. RPC: get all accepted friends for a user ──────────────────────────────
CREATE OR REPLACE FUNCTION public.get_friends(user_id UUID)
RETURNS TABLE (
  id             UUID,
  username       TEXT,
  display_name   TEXT,
  avatar_url     TEXT,
  is_online      BOOLEAN,
  account_number TEXT
)
LANGUAGE sql STABLE AS $$
  SELECT
    p.id, p.username, p.display_name, p.avatar_url,
    p.is_online, p.account_number
  FROM public.profiles p
  JOIN public.friend_requests fr ON (
    (fr.sender_id   = user_id AND fr.receiver_id = p.id) OR
    (fr.receiver_id = user_id AND fr.sender_id   = p.id)
  )
  WHERE fr.status = 'accepted'
    AND p.id <> user_id
  ORDER BY p.display_name, p.username;
$$;

-- ── 7. RPC: check if two users are friends ───────────────────────────────────
CREATE OR REPLACE FUNCTION public.are_friends(user1_id UUID, user2_id UUID)
RETURNS BOOLEAN LANGUAGE sql STABLE AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.friend_requests
    WHERE status = 'accepted'
      AND (
        (sender_id = user1_id AND receiver_id = user2_id) OR
        (sender_id = user2_id AND receiver_id = user1_id)
      )
  );
$$;

-- ── 8. Enable Realtime on friend_requests ────────────────────────────────────
ALTER PUBLICATION supabase_realtime ADD TABLE public.friend_requests;
