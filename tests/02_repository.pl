use strict;
use Test::More tests => 14;

BEGIN { use_ok( "EPrints" ); }
BEGIN { use_ok( "EPrints::Test" ); }

EPrints::Test::mem_increase();

my $repo = EPrints::Test::get_test_repository( 0 );
ok(defined $repo, 'opened an EPrints::Repository object (noisy, no_check_db)');

is($repo->{noise},0,"Correct noise setting?");
is($repo->{online},0,"Correct online setting?");
is($repo->{query},undef,"There should be no query, we're offline");

ok(defined $repo->{config}, "is there a repository config attached?");
ok($repo->isa('EPrints::Repository'), "and it's really an repository");

ok(defined $repo->database, "is there a database attached?");
ok($repo->database->isa('EPrints::Database'), "and it's really an EPrints::Database?");

ok(defined $repo->{lang}, "session has a language set" );
ok($repo->{lang}->isa('EPrints::Language'), "and it's EPrints::Language" );
is($repo->{lang}->{id}, 'en', "and it's the default (english)" );

$repo->terminate;
ok(!defined $repo->{database}, "cleaned up session" );
