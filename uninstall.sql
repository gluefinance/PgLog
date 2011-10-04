REVOKE EXECUTE ON FUNCTION public.PgLog_Import() FROM pglog;
DROP USER pglog;
DROP SCHEMA pglog CASCADE;
DROP FUNCTION public.PgLog_Import();
