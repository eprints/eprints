use strict;
use Test::More tests => 6;

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

$searchexp = EPrints::Search->new(
	session => $session,
	dataset => $dataset,
);

my $sample_doc = EPrints::Test::get_test_document( $session );

$searchexp->add_field( $dataset->get_field( "eprintid" ), $sample_doc->get_value( "eprintid" ) );
$searchexp->add_field( $sample_doc->get_dataset->get_field( "format" ), $sample_doc->get_value( "format" ) );

$searchexp->perform_search;

my $is_ok = 0;
$searchexp->map(sub {
	my( undef, undef, $eprint ) = @_;

	$is_ok = 1 if $eprint->get_id == $sample_doc->get_value( "eprintid" );
});

$searchexp->dispose;

ok($is_ok, "search for eprint id + doc format");

$session->terminate;
