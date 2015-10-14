use strict;
use utf8;
use Test::More tests => 35;

BEGIN { use_ok( "EPrints" ); }
BEGIN { use_ok( "EPrints::Test" ); }

my $session = EPrints::Test::get_test_session( 0 );
ok(defined $session, 'opened an EPrints::Session object (noisy, no_check_db)');

my $dataset = $session->dataset( "eprint" );

my $searchexp = EPrints::Search->new(
	session => $session,
	dataset => $dataset,
	allow_blank => 1,
);

my $list = eval { $searchexp->perform_search };

ok(defined($list) && $list->count > 0, "blank found matches");


$searchexp = EPrints::Search->new(
	session => $session,
	dataset => $dataset,
);

$searchexp->add_field( $dataset->get_field( "eprintid" ), "1-" );

$list = eval { $searchexp->perform_search };

ok(defined($list) && $list->count > 1, "search range eprintid" );

$searchexp = EPrints::Search->new(
	session => $session,
	dataset => $dataset,
	satisfy_all => 1 );

$searchexp->add_field( $dataset->field( "title" ), "eagle", "IN" );
$searchexp->add_field( $dataset->field( "creators_name" ), "Maury, W Parkes, F", "EQ" );

ok(defined($list) && $list->count, "title IN + creators_name GREP\n".$searchexp->get_conditions->describe);

$searchexp = EPrints::Search->new(
	session => $session,
	dataset => $dataset,
);

$searchexp->add_field( $dataset->get_field( "creators_name" ), "", "SET" );
$searchexp->add_field( $dataset->get_field( "metadata_visibility" ), "show" );
$searchexp->add_field( $dataset->get_field( "eprint_status" ), "archive" );

$list = eval { $searchexp->perform_search };

#print STDERR $searchexp->get_conditions->sql( dataset => $dataset, session => $session )."\n";

ok(defined($list) && $list->count > 1, "SET match" );

$searchexp = EPrints::Search->new(
	session => $session,
	dataset => $dataset,
	satisfy_all => 1
);

$searchexp->add_field( $dataset->get_field( "subjects" ), "GR" );
$searchexp->add_field( $dataset->get_field( "divisions" ), "sch_mat" );

$list = eval { $searchexp->perform_search };

ok(defined($list) && $list->count > 0, "subjects and divisions: " . $searchexp->get_conditions->describe );

$searchexp = EPrints::Search->new(
	session => $session,
	dataset => $dataset,
);

$searchexp->add_field( $dataset->get_field( "documents" ), "article", "IN" );

$list = eval { $searchexp->perform_search };

ok(defined($list) && $list->count > 0, "match testdata article full text" );


my $sample_doc = EPrints::Test::get_test_document( $session );
my $sample_eprint = $sample_doc->get_parent;

$searchexp = EPrints::Search->new(
	session => $session,
	dataset => $dataset,
);

$searchexp->add_field( $dataset->get_field( "eprintid" ), $sample_doc->get_value( "eprintid" ) );
$searchexp->add_field( $sample_doc->get_dataset->get_field( "format" ), $sample_doc->get_value( "format" ) );

$list = eval { $searchexp->perform_search };

my $is_ok = 0;
if( defined $list )
{
	my( $eprint ) = $list->get_records( 0, 1 );
	$is_ok = $list->count == 1 && $eprint->get_id == $sample_doc->get_value( "eprintid" );
}

ok($is_ok, "search for eprint id + doc format: " . $searchexp->get_conditions->describe);


$searchexp = EPrints::Search->new(
	session => $session,
	dataset => $dataset,
);

$searchexp->add_field( $dataset->get_field( "creators_name" ), "Neumeier, M" );

$list = eval { $searchexp->perform_search };

ok(defined($list) && $list->count > 0, "search multiple name field".sql($searchexp));


$searchexp = EPrints::Search->new(
	session => $session,
	dataset => $dataset,
	satisfy_all => 0,
);

$searchexp->add_field( $dataset->get_field( "relation_type" ), "NOMATCH" );
$searchexp->add_field( $dataset->get_field( "editors_name" ), "NOMATCH, P" );
$searchexp->add_field( $dataset->get_field( "title" ), "legend", "IN" );

$list = eval { $searchexp->perform_search };

ok(defined($list) && $list->count > 0, "satisfy-any, nomatch multiple");


$searchexp = EPrints::Search->new(
	session => $session,
	dataset => $dataset,
	satisfy_all => 0,
	custom_order => "-date/title",
);

$searchexp->add_field( $dataset->get_field( "creators_name" ), "Smith, John" );
$searchexp->add_field( $sample_doc->get_dataset->get_field( "format" ), "application/pdf" );
$searchexp->add_field( $sample_doc->get_dataset->get_field( "relation_type" ), EPrints::Utils::make_relation("isVolatileVersionOf") );

$list = eval { $searchexp->perform_search };

ok(defined($list) && $list->count > 0, "satisfy/multi datasets/multiple");


$searchexp = EPrints::Search->new(
	session => $session,
	dataset => $dataset,
);

$searchexp->add_field( $dataset->get_field( "subjects" ), "QH" );

$list = eval { $searchexp->perform_search };

ok(defined($list) && $list->count > 0, "subject hierarchy");


$searchexp = EPrints::Search->new(
	session => $session,
	dataset => $dataset,
);

$searchexp->add_field( $dataset->get_field( "subjects" ), "QH" );

my( $values, $counts ) = eval { $searchexp->perform_groupby( $dataset->get_field( "creators_name" ) ) };

ok(defined($values) && scalar(@$values) > 0, "groupby");

my $dataset_size = $dataset->count( $session );
BAIL_OUT( "Can't test empty dataset" ) unless $dataset_size > 0;

my $cond = EPrints::Search::Condition::False->new;

my $matches = $cond->process(
	session => $session,
	dataset => $dataset,
	);

ok(@$matches == 0, "FALSE condition returns empty");

$cond = EPrints::Search::Condition::True->new;

$matches = $cond->process(
	session => $session,
	dataset => $dataset,
	);

ok(@$matches == $dataset_size, "TRUE condition returns everything");

$cond = EPrints::Search::Condition::And->new(
	EPrints::Search::Condition::False->new,
	EPrints::Search::Condition::True->new );

$matches = $cond->process(
	session => $session,
	dataset => $dataset,
	);

ok(@$matches == 0, "TRUE AND FALSE is FALSE");

$cond = EPrints::Search::Condition::Or->new(
	EPrints::Search::Condition::True->new,
	EPrints::Search::Condition::False->new );

$matches = $cond->process(
	session => $session,
	dataset => $dataset,
	);

ok(@$matches == $dataset_size, "TRUE OR FALSE is TRUE");

my $hdataset = $session->dataset( "history" );

my $db = $session->get_database;

my $retry = 0;
HISTORY:

my $sql = "SELECT ".$db->quote_identifier( "userid" )." FROM ".$db->quote_identifier( $hdataset->get_sql_table_name )." WHERE ".$db->quote_identifier( "userid" )." IS NOT NULL";
my $sth = $db->prepare_select( $sql, limit => 1 );
$sth->execute;

my( $userid ) = $sth->fetchrow_array;

undef $sth;

if( !$retry && !defined $userid )
{
	my $eprint = $session->dataset( "eprint" )->search( limit => 1 )->item( 0 );
	BAIL_OUT("No eprints") if !defined $eprint;
	$eprint->save_revision( user => $session->user( 1 ), action => "unit_test" );
	$retry = 1;
	goto HISTORY;
}

BAIL_OUT("Need at least one history object") unless defined $userid;
my $user = EPrints::DataObj::User->new( $session, $userid );

$searchexp = EPrints::Search->new(
	session => $session,
	dataset => $hdataset,
	allow_blank => 1,
	filters => [{ meta_fields => [qw( userid.username )], value => $user->get_value( "username" ) }],
	);

$list = $searchexp->perform_search;
ok($list->count > 0, "history object by username subquery".$searchexp->get_conditions->describe."\n".$searchexp->get_conditions->sql( dataset => $hdataset, session => $session ));

$list = eval { $dataset->search(
	filters => [{ meta_fields => [qw( documents.format )], value => "text" }],
	) };
ok($list->count > 0, "documents.format join path");

my $udataset = $session->dataset( "user" );
my $ssdataset = $session->dataset( "saved_search" );
my @usertypes = $session->get_repository->get_types( "user" );

$searchexp = EPrints::Search->new(
	session => $session,
	dataset => $ssdataset );

$searchexp->add_field(
	$udataset->get_field( "frequency" ),
	"never" );

eval { $searchexp->perform_search };
ok( !$@, "userid->frequency on saved_search" );

$cond = EPrints::Search::Condition::Regexp->new( $udataset, $udataset->get_field( "username" ), '^' . $user->get_value( "username" ) . '$' );
$matches = $cond->process(
	session => $session,
	dataset => $udataset,
	);

is(scalar(@$matches), 1, "regexp username matched itself" );

$searchexp = EPrints::Search->new(
	session => $session,
	dataset => $dataset,
	satisfy_all => 0 );

$searchexp->add_field( $dataset->get_field( "documents" ), "article", "IN" );
$searchexp->add_field( $dataset->get_field( "title" ), "article", "IN" );
$searchexp->add_field( $dataset->get_field( "relation_type" ), "article" );

#print STDERR $searchexp->get_conditions->describe;

$list = $searchexp->perform_search;

ok($list->count > 0, "satisfy_all => 0");

$searchexp = EPrints::Search->new(
	session => $session,
	dataset => $sample_doc->get_dataset,
	satisfy_all => 0 );

$searchexp->add_field( $dataset->get_field( "type" ), "article" );

$list = $searchexp->perform_search;

ok($list->count > 0, "documents.eprint.type/satisfy_all => 0");

$searchexp = EPrints::Search->new(
	session => $session,
	dataset => $session->dataset( "history" ),
	satisfy_all => 0 );

$searchexp->add_field( $session->dataset( "user" )->get_field( "usertype" ), "admin" );

$list = $searchexp->perform_search;

ok($list->count > 0, "query history by user type");

$searchexp = EPrints::Search->new(
	session => $session,
	dataset => $dataset,
	satisfy_all => 0 );

$searchexp->add_field( $session->dataset( "user" )->get_field( "name" ), "Admin, A" );

$list = $searchexp->perform_search;

# name isn't set in test data set
ok(1, "query eprint by user name");

SKIP: {
skip "No support for arbitrary dataset joins yet", 1..1;

$searchexp = EPrints::Search->new(
	session => $session,
	dataset => $sample_doc->get_dataset,
	satisfy_all => 0 );

my $file_dataset = $session->dataset( "file" );
$searchexp->add_field( $file_dataset->get_field( "mime_type" ), "application/pdf" );

$list = $searchexp->perform_search;

ok($list->count > 0, "documents.file.mime_type/satisfy_all => 0");
};

$searchexp = EPrints::Search->new(
    session => $session,
    dataset => $sample_doc->dataset,
    satisfy_all => 0 );

$searchexp->add_field( $sample_doc->dataset->field( "relation" ), "http%3A//eprints.org/relation/islightboxThumbnailVersionOf:/id/document/1", "EX" );

#print STDERR $searchexp->get_conditions->sql( dataset => $sample_doc->dataset, session => $session );

$list = $searchexp->perform_search;

ok($list->count > 0, "compound type field query");

SKIP: {
	skip "not implemented yet", 1;

	$searchexp = EPrints::Search->new(
		session => $session,
		dataset => $dataset,
		satisfy_all => 0 );

	$searchexp->add_field( $dataset->field( "contributors" ), {
		type => "http://www.loc.gov/loc.terms/relators/ACT",
		name => { family => "Léricolais", given => "I." },
	}, "EX" );

	$list = $searchexp->perform_search;

	ok($list->count > 1, "compound type with name query\n".$searchexp->get_conditions->describe."\n".$searchexp->get_conditions->sql( dataset => $dataset, session => $session ));
};

$searchexp = EPrints::Search->new(
	session => $session,
	dataset => $dataset,
	satisfy_all => 0 );

$searchexp->add_field( $dataset->field( "title" ), "eagl*", "IN" );

my $sf = $searchexp->get_searchfield( "title" );
# any better way to check this?
ok( $sf->get_conditions->describe =~ "index_start", "title=eagl* results in index_start" );

$searchexp = EPrints::Search->new(
	session => $session,
	dataset => $dataset,
	satisfy_all => 0 );

$searchexp->add_field( $dataset->field( "title" ), "waxing monkey", "IN" );
$searchexp->add_field( $dataset->field( "date" ), "2000" );

$list = $searchexp->perform_search;

ok($list->count > 0, "title OR date: ".$searchexp->get_conditions->describe);

$searchexp = EPrints::Search->new(
	session => $session,
	dataset => $dataset,
	satisfy_all => 0 );

$searchexp->add_field( $dataset->field( "title" ), "banded geckos", "IN" );
$searchexp->add_field( $dataset->field( "abstract" ), "demonstration data", "IN" );

$list = $searchexp->perform_search;

ok($list->count > 0, "title OR abstract: ".$searchexp->get_conditions->describe."\n".$searchexp->get_conditions->sql( dataset => $dataset, session => $session ));

$searchexp = EPrints::Search->new(
	session => $session,
	dataset => $sample_doc->get_dataset,
);

$searchexp->add_field(
	$sample_doc->get_dataset->get_field( "relation_type" ),
	EPrints::Utils::make_relation("isVolatileVersionOf")." ".EPrints::Utils::make_relation("ispreviewThumbnailVersionOf"), "EQ", "ALL" );

$list = eval { $searchexp->perform_search };

ok(defined($list) && $list->count > 0, "search multiple field".&describe($searchexp).&sql($searchexp));

SKIP:
{
	skip "Enable Xapian", 1 if !defined $session->plugin( "Search::Xapian" );

	my $searchexp = $session->plugin( "Search::Xapian",
			dataset => $dataset,
			search_fields => [
				{ meta_fields => [qw( creators_name )], },
			],
			q => "creators_name:Léricolais",
		);
	my $list = $searchexp->execute;

	ok($list->count > 0, "Xapian creators_name");
}

$session->terminate;

sub describe
{
	return "\n: ".$_[0]->get_conditions->describe;
}

sub sql
{
	return "\n: ".$_[0]->get_conditions->sql(
		session => $_[0]->{session},
		dataset => $_[0]->{dataset},
	);
}
