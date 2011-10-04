CREATE TABLE PgLogFiles (
PgLogFileID integer not null default nextval('seqPgLogFiles'),
Filename text not null,
Active integer not null default 1,
LastSessionID text,
LastSessionLineNum bigint,
PRIMARY KEY (PgLogFileID),
UNIQUE(Filename)
);
