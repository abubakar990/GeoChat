-- ============================================================
--  Migration 005 · Normalize account_number to uppercase
--  and make the column case-insensitively indexed
-- ============================================================

-- Ensure all existing account numbers are uppercase (GEO-XXXXXXXX)
UPDATE public.profiles
SET account_number = UPPER(account_number)
WHERE account_number IS NOT NULL
  AND account_number <> UPPER(account_number);

-- Add a case-insensitive index so searches are fast
CREATE INDEX IF NOT EXISTS idx_profiles_account_number_upper
  ON public.profiles (UPPER(account_number));

DO $$
DECLARE n INT;
BEGIN
  SELECT COUNT(*) INTO n FROM public.profiles WHERE account_number IS NULL;
  RAISE NOTICE 'Profiles still missing account_number: %', n;
  SELECT COUNT(*) INTO n FROM public.profiles WHERE account_number IS NOT NULL;
  RAISE NOTICE 'Profiles with account_number: %', n;
END;
$$;
