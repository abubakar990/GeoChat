-- ============================================================
--  Migration 002 · Friend System + Account Numbers
--  Safe to re-run: drops policies before recreating
-- ============================================================

-- ── Account number generator ─────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION generate_account_number()
RETURNS TEXT LANGUAGE plpgsql AS $$
DECLARE num TEXT;
BEGIN
  LOOP
    num := 'GEO-' || upper(substring(encode(gen_random_bytes(4), 'hex'), 1, 8));
    EXIT WHEN NOT EXISTS (SELECT 1 FROM public.profiles WHERE account_number = num);
  END LOOP;
  RETURN num;
END;
$$;

-- ── account_number column ────────────────────────────────────────────────────
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS account_number TEXT UNIQUE DEFAULT NULL;

UPDATE public.profiles SET account_number = generate_account_number()
  WHERE account_number IS NULL;

-- ── Trigger ──────────────────────────────────────────────────────────────────
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

-- ── friend_requests table ────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.friend_requests (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  sender_id   UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  receiver_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  status      TEXT NOT NULL DEFAULT 'pending'
                CHECK (status IN ('pending', 'accepted', 'rejected')),
  created_at  TIMESTAMPTZ DEFAULT NOW(),
  updated_at  TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE (sender_id, receiver_id)
);

CREATE INDEX IF NOT EXISTS idx_fr_receiver ON public.friend_requests(receiver_id, status);
CREATE INDEX IF NOT EXISTS idx_fr_sender   ON public.friend_requests(sender_id, status);

-- ── RLS ───────────────────────────────────────────────────────────────────────
ALTER TABLE public.friend_requests ENABLE ROW LEVEL SECURITY;

-- Drop then recreate to avoid "already exists" errors on re-run
DROP POLICY IF EXISTS "fr_select_participant" ON public.friend_requests;
DROP POLICY IF EXISTS "fr_insert_sender"      ON public.friend_requests;
DROP POLICY IF EXISTS "fr_update_receiver"    ON public.friend_requests;

CREATE POLICY "fr_select_participant"
  ON public.friend_requests FOR SELECT
  USING (auth.uid() = sender_id OR auth.uid() = receiver_id);

CREATE POLICY "fr_insert_sender"
  ON public.friend_requests FOR INSERT
  WITH CHECK (auth.uid() = sender_id);

CREATE POLICY "fr_update_receiver"
  ON public.friend_requests FOR UPDATE
  USING (auth.uid() = receiver_id);

-- ── RPCs ─────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.get_friends(user_id UUID)
RETURNS TABLE (
  id UUID, username TEXT, display_name TEXT,
  avatar_url TEXT, is_online BOOLEAN, account_number TEXT
)
LANGUAGE sql STABLE AS $$
  SELECT p.id, p.username, p.display_name, p.avatar_url, p.is_online, p.account_number
  FROM public.profiles p
  JOIN public.friend_requests fr ON (
    (fr.sender_id = user_id AND fr.receiver_id = p.id) OR
    (fr.receiver_id = user_id AND fr.sender_id = p.id)
  )
  WHERE fr.status = 'accepted' AND p.id <> user_id
  ORDER BY p.display_name, p.username;
$$;

CREATE OR REPLACE FUNCTION public.are_friends(user1_id UUID, user2_id UUID)
RETURNS BOOLEAN LANGUAGE sql STABLE AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.friend_requests
    WHERE status = 'accepted'
      AND ((sender_id = user1_id AND receiver_id = user2_id)
        OR (sender_id = user2_id AND receiver_id = user1_id))
  );
$$;

-- ── Realtime (safe: only adds if not already in publication) ─────────────────
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime'
      AND schemaname = 'public'
      AND tablename  = 'friend_requests'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.friend_requests;
  END IF;
END;
$$;
