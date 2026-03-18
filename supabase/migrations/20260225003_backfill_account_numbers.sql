-- ============================================================
--  Migration 003 · Backfill account_number for existing users
--  Safe to re-run
-- ============================================================

-- Make sure generate_account_number exists (from migration 002)
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

-- Add column if somehow missing
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS account_number TEXT UNIQUE DEFAULT NULL;

-- Backfill any existing rows that still have NULL account_number
DO $$
DECLARE
  rec RECORD;
BEGIN
  FOR rec IN
    SELECT id FROM public.profiles WHERE account_number IS NULL
  LOOP
    UPDATE public.profiles
    SET account_number = generate_account_number()
    WHERE id = rec.id;
  END LOOP;
END;
$$;
