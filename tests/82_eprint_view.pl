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
	path => "/cgi/users/home",
	username => "admin",
	query => {
		screen => "EPrint::View::Editor",
		eprintid => $eprintid,
	},
});

EPrints::ScreenProcessor->process(
	handle => $handle,
	url => $handle->get_repository->get_conf( "base_url" ) . "/cgi/users/home"
	);

$handle->terminate;

my $content = $handle->test_get_stdout();

#diag($content);

ok(1);
