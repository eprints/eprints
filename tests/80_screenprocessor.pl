use strict;
use Test::More tests => 4;

BEGIN { use_ok( "EPrints" ); }
BEGIN { use_ok( "EPrints::Test" ); }
BEGIN { use_ok( "EPrints::ScreenProcessor" ); }

my $handle = EPrints::Test::get_test_session();
$handle = EPrints::Test::OnlineSession->new( $handle, {
	method => "GET",
	path => "/cgi/users/home",
	username => "admin",
});

EPrints::ScreenProcessor->process(
	handle => $handle,
	url => $handle->get_repository->get_conf( "base_url" ) . "/cgi/users/home"
	);

my $content = $handle->test_get_stdout();

$handle->terminate;

#diag($content);

ok(1);
