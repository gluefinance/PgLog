CREATE LANGUAGE plperlu;
CREATE LANGUAGE plpgsql;

CREATE USER pglog;
CREATE SCHEMA pglog;

SET search_path TO pglog;

\i sequences/seqPgLogFiles.sql
\i sequences/seqPgLogPatterns.sql
\i sequences/seqPgLogRows.sql
\i sequences/seqPgLogStats.sql

\i tables/PgLogFiles.sql
\i tables/PgLogPatterns.sql
\i tables/PgLogRows.sql
\i tables/PgLogStats.sql

\i views/View_PgLog_Last.sql
\i views/View_PgLog_Notice.sql
\i views/View_PgLog_Patterns.sql
\i views/View_PgLog_Stats.sql

\i functions/PgLog_Get_Files.sql
\i functions/New_SMS.sql

SET search_path TO public;

\i functions/PgLog_Import.sql

GRANT EXECUTE ON FUNCTION public.PgLog_Import() TO pglog;
