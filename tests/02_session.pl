use strict;
use Test::More tests => 16;

BEGIN { use_ok( "EPrints" ); }
BEGIN { use_ok( "EPrints::Test" ); }

EPrints::Test::mem_increase();

my $session = EPrints::Test::get_test_session( 0 );
ok(defined $session, 'opened an EPrints::Session object (noisy, no_check_db)');

# check it's the right type
ok($session->isa('EPrints::Session'),'it really was an EPrints::Session');

is($session->{noise},0,"Correct noise setting?");
is($session->{offline},1,"Correct offline setting?");
is($session->{query},undef,"There should be no query, we're offline");

ok(defined $session->get_repository, "is there a repository config attached?");
ok($session->get_repository->isa('EPrints::Repository'), "and it's really an repository");

ok(defined $session->get_database, "is there a database attached?");
ok($session->get_database->isa('EPrints::Database'), "and it's really an EPrints::Database?");

ok(defined $session->{doc}, "is there a XML base document?");

ok(defined $session->{lang}, "session has a language set" );
ok($session->{lang}->isa('EPrints::Language'), "and it's EPrints::Language" );
is($session->{lang}->{id}, 'en', "and it's the default (english)" );

$session->terminate;
ok(!defined $session->{database}, "cleaned up session" );
