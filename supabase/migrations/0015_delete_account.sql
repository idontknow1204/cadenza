-- 0015_delete_account.sql
-- SECURITY DEFINER function so authenticated users can permanently delete their own account.
-- Deleting from public.profiles cascades (via FK) to all public.* tables.
-- Then deleting from auth.users removes the auth record.

CREATE OR REPLACE FUNCTION delete_my_account()
RETURNS VOID
LANGUAGE PLPGSQL
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
    DELETE FROM public.profiles WHERE id = auth.uid();
    DELETE FROM auth.users WHERE id = auth.uid();
END;
$$;

GRANT EXECUTE ON FUNCTION delete_my_account() TO authenticated;
