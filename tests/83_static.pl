use strict;
use Test::More tests => 5;

BEGIN { use_ok( "EPrints" ); }
BEGIN { use_ok( "EPrints::Test" ); }

my $session = EPrints::Test::get_test_session();

# find an example eprint
my $dataset = $session->dataset( "eprint" );
my( $eprintid ) = @{ $dataset->get_item_ids( $session ) };

$session = EPrints::Test::OnlineSession->new( $session, {
	method => "GET",
	path => "/",
	query => {},
});

EPrints::Apache::Rewrite::handler( $session->get_request );
ok(defined $session->get_request->filename, "rewrite set filename");

EPrints::Apache::Template::handler( $session->get_request );

my $content = $session->test_get_stdout();
ok( $content, "content generated" );

ok(1);
