CREATE OR REPLACE FUNCTION public.get_impacted_accounts(IN text)
RETURNS SETOF text AS '$libdir/hfm-@GIT_REVISION@.so', 'get_impacted_accounts' LANGUAGE C;
