use strict;
use Test::More tests => 9;

BEGIN { use_ok( "EPrints" ); }
BEGIN { use_ok( "EPrints::Test" ); }

my $session = EPrints::Test::get_test_session( 0 );
ok(defined $session, 'opened an EPrints::Session object');

my $database = $session->get_database();
ok( defined $database, "database defined" );

my $dataset = $session->dataset( "cachemap" );

my $cachemap;

$cachemap = $dataset->create_dataobj( {
	oneshot => 'TRUE',
} );
$cachemap->create_sql_table( $dataset );
ok( $database->has_table( $cachemap->get_sql_table_name ), "create_sql_table" );

&cleanup();

my $fake_time = time() - 2 * 3600;

for(1..10)
{
	$cachemap = $dataset->create_dataobj( {
		oneshot => 'TRUE',
		created => $fake_time,
	} );
	$cachemap->create_sql_table( $dataset );
}

$cachemap = $dataset->create_dataobj( {
	oneshot => 'TRUE',
} );
$cachemap->create_sql_table( $dataset );

do {
	local $session->{config}->{cache_maxlife} = 1;
	BAIL_OUT "Expected to set config but didn't" if $session->config( "cache_maxlife" ) != 1;

	my $dropped = EPrints::DataObj::Cachemap->cleanup( $session );

	is( $dropped, 10, "expired all old cachemaps" );
	is( $session->get_database->count_table( $dataset->get_sql_table_name ), 1, "didn't expire current cachemap" );
};

&cleanup();

do {
	local $session->{config}->{cache_max} = 5;
	for(1..10)
	{
		my $cachemap = $dataset->create_dataobj( {
			oneshot => 'TRUE',
			created => $fake_time,
		} );
		$cachemap->create_sql_table( $dataset );
	}
	is( $session->get_database->count_table( $dataset->get_sql_table_name ), 5, "cache_max limits tables created" );
};

&cleanup();

$session->terminate;

ok(1);

sub cleanup
{
# clear all current cachemaps
	$dataset->search->map(sub {
		my( undef, undef, $cachemap ) = @_;

		$cachemap->remove;
	} );
}
