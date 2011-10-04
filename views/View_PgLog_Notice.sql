CREATE VIEW View_PgLog_Notice AS
SELECT
    PgLogRows.PgLogRowID,
    PgLogRows.LogTime,
    PgLogRows.Username,
    PgLogRows.Message
FROM PgLogRows
JOIN PgLogPatterns USING (PgLogPatternID)
WHERE PgLogPatterns.ErrorSeverity = 'NOTICE'
ORDER BY PgLogRows.PgLogRowID DESC
LIMIT 100;
