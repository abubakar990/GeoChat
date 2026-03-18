-- Temporary: just log all account numbers so we can verify
DO $$
DECLARE rec RECORD;
BEGIN
  FOR rec IN SELECT username, account_number FROM public.profiles ORDER BY created_at LOOP
    RAISE NOTICE 'User: % | Account: %', rec.username, rec.account_number;
  END LOOP;
END;
$$;
