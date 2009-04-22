use strict;
use Test::More tests => 5;

BEGIN { use_ok( "EPrints" ); }
BEGIN { use_ok( "EPrints::Test" ); }

my $session = EPrints::Test::get_test_session( 0 );
ok(defined $session, 'opened an EPrints::Session object (noisy, no_check_db)');

my $dataset = $session->get_repository->get_dataset( "eprint" );

my $searchexp = EPrints::Search->new(
	session => $session,
	dataset => $dataset,
	allow_blank => 1,
);

my $list = $searchexp->perform_search;

ok(defined($list) && $list->count > 0, "blank found matches");

$searchexp->dispose;

$searchexp = EPrints::Search->new(
	session => $session,
	dataset => $dataset,
);

$searchexp->add_field( $dataset->get_field( "_fulltext_" ), "article", "IN" );

$list = $searchexp->perform_search;

ok(defined($list) && $list->count > 0, "match testdata article full text" );

$searchexp->dispose;

$session->terminate;
