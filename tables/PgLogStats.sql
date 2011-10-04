CREATE TABLE PgLogStats (
PgLogStatID integer not null default nextval('seqPgLogStats'),
PgLogPatternID integer not null,
LogDate date not null,
Count integer not null default 1,
LastLogTime timestamptz not null,
PRIMARY KEY (PgLogStatID),
FOREIGN KEY (PgLogPatternID) REFERENCES PgLogPatterns(PgLogPatternID),
UNIQUE(PgLogPatternID,LogDate)
);
