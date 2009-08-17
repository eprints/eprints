use strict;
use Test::More tests => 4;

BEGIN { use_ok( "EPrints" ); }
BEGIN { use_ok( "EPrints::Test" ); }
BEGIN { use_ok( "EPrints::ScreenProcessor" ); }

my $handle = EPrints::Test::get_test_session();

# find an example eprint
my $dataset = $handle->get_repository->get_dataset( "eprint" );
my( $eprintid ) = @{ $dataset->get_item_ids( $handle ) };

$handle = EPrints::Test::OnlineSession->new( $handle, {
	method => "GET",
	path => "/cgi/search/simple",
	query => {
		q => "demonstration",
		_action_search => "Search",
		_order => "bytitle",
	},
});

my $sconf = $handle->get_repository->get_conf( "search", "simple" );

EPrints::ScreenProcessor->process( 
	handle => $handle, 
	url => $handle->get_repository->get_conf( "perl_url" )."/search/simple",
	sconf => $sconf,
	template => $sconf->{template},
	screenid => "Public::EPrintSearch",
);

#print STDERR $handle->test_get_stdout;

ok(1);
