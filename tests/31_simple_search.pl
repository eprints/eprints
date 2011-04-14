use strict;
use Test::More tests => 4;

BEGIN { use_ok( "EPrints" ); }
BEGIN { use_ok( "EPrints::Test" ); }
BEGIN { use_ok( "EPrints::ScreenProcessor" ); }

my $session = EPrints::Test::get_test_session();

# find an example eprint
my $dataset = $session->get_repository->get_dataset( "eprint" );
my( $eprintid ) = @{ $dataset->get_item_ids( $session ) };

$session = EPrints::Test::OnlineSession->new( $session, {
	method => "GET",
	path => "/cgi/search/simple",
	query => {
		q => "demonstration",
		_action_search => "Search",
		_order => "bytitle",
	},
});

my $sconf = $session->config( "search", "simple" );

EPrints::ScreenProcessor->process( 
	session => $session, 
	url => $session->config( "perl_url" )."/search/simple",
	sconf => $sconf,
	template => $sconf->{template},
	screenid => "Search",
);

#print STDERR $session->test_get_stdout;

ok(1);
