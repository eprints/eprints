use strict;
use Test::More tests => 6;

BEGIN { use_ok( "EPrints" ); }
BEGIN { use_ok( "EPrints::Test" ); }

my $session = EPrints::Test::get_test_session( 0 );
ok(defined $session, 'opened an EPrints::Session object');

my $database = $session->get_database();
ok( defined $database, "database defined" );

my $dataset = $session->dataset( "eprint" );

SKIP: {
	skip "Only supports MySQL", 1 unless $database->isa( "EPrints::Database::mysql" );

	ok($database->index_name(
		$dataset->get_sql_table_name,
		$dataset->field( "datestamp" )->get_sql_index
	), "index_name(eprint.datestamp)");
}

ok(1);
