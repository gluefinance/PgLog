CREATE OR REPLACE FUNCTION PgLog_Get_Files(OUT Filename text, _LogDir text) RETURNS SETOF TEXT AS $BODY$
use strict;
use warnings;

use DirHandle;
use DateTime;

my $log_dir = $_[0];

my $d = DirHandle->new($log_dir);
return undef unless defined $d;
my $dt = DateTime->now();
my $today = $dt->add(days => 1)->ymd('-');
$dt->subtract(days => 1);
my $yesterday = $dt->ymd('-');
while (my $f = $d->read) {
    next unless $f =~ m/($today|$yesterday).*\.csv$/;
    return_next($log_dir . $f);
}
undef $d;
return;
$BODY$ LANGUAGE plperlu VOLATILE;
