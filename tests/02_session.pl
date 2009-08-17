use strict;
use Test::More tests => 16;

BEGIN { use_ok( "EPrints" ); }
BEGIN { use_ok( "EPrints::Test" ); }

EPrints::Test::mem_increase();

my $handle = EPrints::Test::get_test_session( 0 );
ok(defined $handle, 'opened an EPrints::Handle object (noisy, no_check_db)');

# check it's the right type
ok($handle->isa('EPrints::Handle'),'it really was an EPrints::Handle');

is($handle->{noise},0,"Correct noise setting?");
is($handle->{offline},1,"Correct offline setting?");
is($handle->{query},undef,"There should be no query, we're offline");

ok(defined $handle->get_repository, "is there a repository config attached?");
ok($handle->get_repository->isa('EPrints::Repository'), "and it's really an repository");

ok(defined $handle->get_database, "is there a database attached?");
ok($handle->get_database->isa('EPrints::Database'), "and it's really an EPrints::Database?");

ok(defined $handle->{doc}, "is there a XML base document?");

ok(defined $handle->{lang}, "session has a language set" );
ok($handle->{lang}->isa('EPrints::Language'), "and it's EPrints::Language" );
is($handle->{lang}->{id}, 'en', "and it's the default (english)" );

$handle->terminate;
ok(!defined $handle->{database}, "cleaned up session" );
