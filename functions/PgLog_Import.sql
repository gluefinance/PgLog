CREATE OR REPLACE FUNCTION PgLog_Import() RETURNS BOOLEAN AS $BODY$
-- Parse through all Postgres log files and import relevant log entires to the database.
-- Also updates the statistics for each error type.
DECLARE
_Active integer;
_Filename text;
_PgLogFileID integer;
_PgLogPatternID integer;
_PgLogStatID integer;
_PgLogRowID integer;
_LogRows boolean;
_LastSessionID text;
_LastSessionLineNum bigint;
_ record;
_SkipForward boolean;
_SMSReceivers text[];
_LastLogTime timestamptz;
_LogDir text;
BEGIN

-- CREATE TEMP TABLE raises NOTICE, silence message to prevent log spamming
SET LOCAL log_min_messages = 'warning';
SET LOCAL client_min_messages = 'warning';
SET LOCAL log_min_duration_statement = '1000 ms';

-- Auto populate PgLogPatterns from source code
INSERT INTO PgLogPatterns (ErrorSeverity,Pattern)
SELECT DISTINCT 'ERROR',(regexp_matches(prosrc,'ERROR_[A-Z0-9_]+','g'))[1] FROM pg_proc WHERE prosrc LIKE '%ERROR_%'
EXCEPT
SELECT ErrorSeverity,Pattern FROM PgLogPatterns
;

INSERT INTO PgLogPatterns (ErrorSeverity,Pattern)
SELECT DISTINCT 'WARNING',(regexp_matches(prosrc,'WARNING_[A-Z0-9_]+','g'))[1] FROM pg_proc WHERE prosrc LIKE '%WARNING_%'
EXCEPT
SELECT ErrorSeverity,Pattern FROM PgLogPatterns
;

INSERT INTO PgLogPatterns (ErrorSeverity,Pattern)
SELECT DISTINCT 'NOTICE',(regexp_matches(prosrc,'NOTICE_[A-Z0-9_]+','g'))[1] FROM pg_proc WHERE prosrc LIKE '%NOTICE_%'
EXCEPT
SELECT ErrorSeverity,Pattern FROM PgLogPatterns
;

-- Populate common PostgreSQL errors
INSERT INTO PgLogPatterns (ErrorSeverity,Pattern)
SELECT 'LOG','unexpected EOF on client connection'
UNION
SELECT 'LOG','could not receive data from client'
UNION
SELECT 'LOG','still waiting for %Lock on transaction'
UNION
SELECT 'LOG','acquired ShareLock on transaction'
UNION
SELECT 'LOG','still waiting for ExclusiveLock on tuple'
UNION
SELECT 'LOG','acquired ExclusiveLock on tuple'
UNION
SELECT 'FATAL','the database system is shutting down'
UNION
SELECT 'FATAL','terminating connection due to administrator command'
UNION
SELECT 'LOG','detected deadlock'
UNION
SELECT 'ERROR','detected deadlock'
UNION
SELECT 'ERROR',''
UNION
SELECT 'FATAL',''
UNION
SELECT 'PANIC',''
UNION
SELECT 'WARNING',''
EXCEPT
SELECT ErrorSeverity,Pattern FROM PgLogPatterns
;

-- Create temp table to temporarily store each imported file into
-- Table will be truncated between each file
CREATE TEMP TABLE TempPostgresLog (
LogTime timestamp(3) with time zone,
UserName text,
DatabaseName text,
ProcessID integer,
ConnectionFrom text,
SessionID text,
SessionLineNum bigint,
CommandTag text,
SessionStartTime timestamp with time zone,
VirtualTransactionID text,
TransactionID bigint,
ErrorSeverity text,
SqlStateCode text,
Message text,
Detail text,
Hint text,
InternalQuery text,
InternalQueryPos integer,
Context text,
Query text,
QueryPos integer,
Location text,
PRIMARY KEY (SessionID, SessionLineNum)
) ON COMMIT DROP;

IF current_setting('server_version') LIKE '9%' THEN
    -- Version 9 also has the application name column
    ALTER TABLE TempPostgresLog ADD COLUMN ApplicationName text;
END IF;

_LogDir := current_setting('data_directory') || '/' || current_setting('log_directory') || '/';
-- Get log files, sorted by filename, last entry will be the active file (most recent)
FOR _Filename IN SELECT Filename FROM PgLog_Get_Files(_LogDir) ORDER BY Filename LOOP

    -- RAISE DEBUG 'Filename %', _Filename;

    -- Check if we already have this file

    SELECT PgLogFileID, Active, LastSessionID, LastSessionLineNum INTO _PgLogFileID, _Active, _LastSessionID, _LastSessionLineNum FROM PgLogFiles WHERE Filename = _Filename;
    IF FOUND THEN
        -- File already exists
        IF _Active = 0 THEN
            -- File closed, no more log entries will be imported
            -- RAISE DEBUG 'File % closed, continue', _Filename;
            CONTINUE;
        ELSIF _Active = 1 THEN
            RAISE DEBUG 'File % active, proceed', _Filename;
            -- Active file, proceed
            IF _LastSessionID IS NOT NULL AND _LastSessionLineNum IS NOT NULL THEN
                -- Skip forward to the row were we stopped time
                _SkipForward := TRUE;
            END IF;
        ELSE
            RAISE EXCEPTION 'ERROR_WTF Unexpected value of Active %', _Active;
        END IF;
    ELSE
        -- New file
        UPDATE PgLogFiles SET Active = 0 WHERE Active = 1;
        INSERT INTO PgLogFiles (Filename) VALUES (_Filename) RETURNING PgLogFileID INTO STRICT _PgLogFileID;
        RAISE LOG 'New file %, proceeed', _Filename;
    END IF;
    TRUNCATE TempPostgresLog;
    IF _Filename ~ '^[a-zA-Z0-9_./-]+$' THEN
        -- OK
    ELSE
        RAISE EXCEPTION 'ERROR_WTF Invalid characters in filename, %', _Filename;
    END IF;

    -- Import file to temporary table
    EXECUTE 'COPY TempPostgresLog FROM ''' || _Filename || ''' WITH CSV';

    IF current_setting('server_version') NOT LIKE '9%' THEN
        -- Version below 9 does not have the application name column,
        -- but add it and let it be NULL to avoid breaking the query further below
        ALTER TABLE TempPostgresLog ADD COLUMN ApplicationName text;
    END IF;

    -- For each log entry...
    FOR _ IN SELECT * FROM TempPostgresLog LOOP

        IF _SkipForward IS TRUE THEN
            -- We have already processed part of the file, continue were we stopped last time (normally last end-of-file unless max log processing time was exceeded)
            IF _.SessionID = _LastSessionID AND _.SessionLineNum = _LastSessionLineNum THEN
                RAISE DEBUG 'Continuing at row SessionID % SessionLineNum %', _LastSessionID, _LastSessionLineNum;
                _SkipForward := FALSE;
                CONTINUE;
            ELSE
                CONTINUE;
            END IF;
        END IF;

        PERFORM 1 FROM PgLogRows WHERE SessionID = _.SessionID AND SessionLineNum = _.SessionLineNum;
        IF FOUND THEN
            -- Already imported, skip
            RAISE DEBUG 'Log entry already imported %', _;
            CONTINUE;
        END IF;

        -- Quit processing after X seconds
        IF clock_timestamp() - now() > '30 seconds'::interval THEN
            RAISE DEBUG 'Max log processing time exceeded, quitting';
            -- Keep track of the last processed row so we can continue
            UPDATE PgLogFiles SET LastSessionID = _.SessionID, LastSessionLineNum = _.SessionLineNum WHERE PgLogFileID = _PgLogFileID;
            RETURN TRUE;
        END IF;

        -- RAISE DEBUG 'Got entry %', _;

        -- Match message against patterns for given error severity. Try longest pattern first.
        SELECT PgLogPatternID, LogRows, SMSReceivers, LastLogTime INTO _PgLogPatternID, _LogRows, _SMSReceivers, _LastLogTime FROM PgLogPatterns WHERE ErrorSeverity = _.ErrorSeverity AND _.Message LIKE ('%' || Pattern || '%') ORDER BY length(Pattern) DESC;
        IF FOUND THEN
            -- RAISE DEBUG 'Matched pattern %', _PgLogPatternID;

            UPDATE PgLogPatterns
            SET Count = Count + 1, LastLogTime = _.LogTime
            WHERE PgLogPatternID = _PgLogPatternID;

            UPDATE PgLogStats
            SET Count = Count + 1, LastLogTime = _.LogTime
            WHERE PgLogPatternID = _PgLogPatternID
            AND LogDate = _.LogTime::date
            RETURNING PgLogStatID INTO _PgLogStatID;

            IF NOT FOUND THEN
                INSERT INTO PgLogStats (PgLogPatternID,LogDate,LastLogTime) VALUES (_PgLogPatternID,_.LogTime::date,_.LogTime) RETURNING PgLogStatID INTO STRICT _PgLogStatID;
            END IF;
        END IF;

        IF _SMSReceivers IS NOT NULL AND now() - _LastLogTime > '1 hour'::interval THEN
            PERFORM New_SMS(unnest,_.Message,'PgLog') FROM unnest(_SMSReceivers);
        END IF;

        IF _LogRows IS TRUE THEN
            -- Go ahead and log
        ELSE
            -- Ignore
            CONTINUE;
        END IF;

        -- Log entry
        INSERT INTO PgLogRows (
            LogTime,
            UserName,
            DatabaseName,
            ProcessID,
            ConnectionFrom,
            SessionID,
            SessionLineNum,
            CommandTag,
            SessionStartTime,
            VirtualTransactionID,
            TransactionID,
            ErrorSeverity,
            SqlStateCode,
            Message,
            Detail,
            Hint,
            InternalQuery,
            InternalQueryPos,
            Context,
            Query,
            QueryPos,
            Location,
            Filename,
            PgLogPatternID,
            PgLogFileID,
            ApplicationName
        ) VALUES (
            _.LogTime,
            _.UserName,
            _.DatabaseName,
            _.ProcessID,
            _.ConnectionFrom,
            _.SessionID,
            _.SessionLineNum,
            _.CommandTag,
            _.SessionStartTime,
            _.VirtualTransactionID,
            _.TransactionID,
            _.ErrorSeverity,
            _.SqlStateCode,
            _.Message,
            _.Detail,
            _.Hint,
            _.InternalQuery,
            _.InternalQueryPos,
            _.Context,
            _.Query,
            _.QueryPos,
            _.Location,
            _Filename,
            _PgLogPatternID,
            _PgLogFileID,
            _.ApplicationName
        ) RETURNING PgLogRowID INTO STRICT _PgLogRowID;
        -- RAISE DEBUG 'Inserted PgLogRowID %', _PgLogRowID;

    END LOOP;

    -- Keep track of the last processed row so we can continue
    UPDATE PgLogFiles SET LastSessionID = _.SessionID, LastSessionLineNum = _.SessionLineNum WHERE PgLogFileID = _PgLogFileID;
END LOOP;

-- All log entries processed successfully
RETURN TRUE;
END;
$BODY$ LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = pglog;