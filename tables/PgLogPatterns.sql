CREATE TABLE PgLogPatterns (
PgLogPatternID integer not null default nextval('seqPgLogPatterns'),
ErrorSeverity text not null,
Pattern text not null,
Count integer not null default 0,
LastLogTime timestamptz,
LogRows boolean not null default false,
SMSReceivers text[],
PRIMARY KEY (PgLogPatternID),
UNIQUE(ErrorSeverity,Pattern)
);
