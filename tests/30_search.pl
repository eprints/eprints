use strict;
use Test::More tests => 9;

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
my $sample_eprint = $sample_doc->get_parent;

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

$searchexp = EPrints::Search->new(
	session => $session,
	dataset => $sample_doc->get_dataset,
);

$searchexp->add_field( $sample_doc->get_dataset->get_field( "relation_type" ), EPrints::Utils::make_relation("isVolatileVersionOf")." ".EPrints::Utils::make_relation("ispreviewThumbnailVersionOf"), "EQ", "ALL" );

my $count = $searchexp->perform_search->count;

ok($count > 0, "search multiple field");

$searchexp->dispose;

$searchexp = EPrints::Search->new(
	session => $session,
	dataset => $dataset,
);

$searchexp->add_field( $dataset->get_field( "creators_name" ), "Neumeier, M" );

ok($searchexp->perform_search->count > 0, "search multiple name field");

$searchexp->dispose;

$searchexp = EPrints::Search->new(
	session => $session,
	dataset => $dataset,
	satisfy_all => 0,
	custom_order => "-date/title",
);

$searchexp->add_field( $dataset->get_field( "creators_name" ), "Smith, John" );
$searchexp->add_field( $sample_doc->get_dataset->get_field( "format" ), "application/pdf" );
$searchexp->add_field( $sample_doc->get_dataset->get_field( "relation_type" ), EPrints::Utils::make_relation("isVolatileVersionOf") );

ok($searchexp->perform_search->count > 0, "satisfy/multi datasets/multiple");

$searchexp->dispose;

$session->terminate;
