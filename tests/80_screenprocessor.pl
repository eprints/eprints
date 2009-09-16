use strict;
use Test::More tests => 4;

BEGIN { use_ok( "EPrints" ); }
BEGIN { use_ok( "EPrints::Test" ); }
BEGIN { use_ok( "EPrints::ScreenProcessor" ); }

my $session = EPrints::Test::get_test_session();
$session = EPrints::Test::OnlineSession->new( $session, {
	method => "GET",
	path => "/cgi/users/home",
	username => "admin",
});

EPrints::ScreenProcessor->process(
	session => $session,
	url => $session->get_repository->get_conf( "base_url" ) . "/cgi/users/home"
	);

$session->terminate;

my $content = $session->test_get_stdout();

#diag($content);

ok(1);
