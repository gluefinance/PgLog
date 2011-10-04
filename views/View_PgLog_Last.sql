CREATE VIEW View_PgLog_Last AS
SELECT
    PgLogRows.PgLogRowID,
    PgLogRows.LogTime,
    PgLogRows.Username,
    PgLogRows.DatabaseName,
    PgLogRows.ProcessID,
    PgLogRows.ConnectionFrom,
    PgLogRows.SessionID,
    PgLogRows.SessionLineNum,
    PgLogRows.CommandTag,
    PgLogRows.SessionStartTime,
    PgLogRows.VirtualTransactionID,
    PgLogRows.TransactionID,
    PgLogRows.ErrorSeverity,
    PgLogRows.SQLStateCode,
    PgLogRows.Message,
    PgLogRows.Detail,
    PgLogRows.Hint,
    PgLogRows.InternalQuery,
    PgLogRows.InternalQuerypos,
    PgLogRows.Context,
    PgLogRows.Query,
    PgLogRows.Querypos,
    PgLogRows.Location,
    PgLogRows.Filename,
    PgLogRows.PgLogPatternID,
    PgLogRows.PgLogFileID,
    PgLogRows.ApplicationName
FROM PgLogRows
ORDER BY PgLogRows.PgLogRowID DESC
LIMIT 100;