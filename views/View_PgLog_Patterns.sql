CREATE VIEW View_PgLog_Patterns AS
SELECT
    PgLogPatterns.PgLogPatternID,
    PgLogPatterns.ErrorSeverity,
    PgLogPatterns.Pattern,
    PgLogPatterns.Count,
    PgLogPatterns.LastLogTime,
    PgLogPatterns.LogRows,
    PgLogPatterns.SmsReceivers
FROM PgLogPatterns
ORDER BY PgLogPatterns.Pattern;
