CREATE VIEW View_PgLog_Stats AS
SELECT
    PgLogStats.PgLogstatid,
    PgLogPatterns.Errorseverity,
    PgLogPatterns.Pattern,
    PgLogStats.Logdate,
    PgLogStats.Count,
    PgLogStats.LastLogTime
FROM PgLogStats
JOIN PgLogPatterns USING (PgLogPatternID)
ORDER BY PgLogStats.LastLogTime DESC
LIMIT 100;
