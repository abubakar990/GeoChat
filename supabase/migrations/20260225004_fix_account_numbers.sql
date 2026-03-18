-- ============================================================
--  Migration 004 · Fix account_number for users who signed in
--  before the trigger existed
--  Also ensures backfill via direct UPDATE (not just SELECT-loop)
-- ============================================================

-- Re-run the backfill as a direct UPDATE using the function
UPDATE public.profiles
SET account_number = generate_account_number()
WHERE account_number IS NULL;

-- Verify: log count (won't affect data, just helpful during review)
DO $$
DECLARE n INT;
BEGIN
  SELECT COUNT(*) INTO n FROM public.profiles WHERE account_number IS NULL;
  IF n > 0 THEN
    RAISE WARNING 'Still % profiles without account_number after backfill', n;
  ELSE
    RAISE NOTICE 'All profiles now have an account_number ✓';
  END IF;
END;
$$;
