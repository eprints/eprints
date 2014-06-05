use strict;
use Test::More tests => 6;

BEGIN { use_ok( "EPrints" ); }
BEGIN { use_ok( "EPrints::Test" ); }

EPrints::Test::mem_increase();

my $repo = EPrints::Test::get_test_repository( 0 );

# $repo->{debug}->{security} = 1;

my $testds = EPrints::Test::get_test_dataset( $repo );
ok(defined $testds, 'loaded test dataset');

my $testobj = $testds->create_dataobj( {} );
ok(defined $testobj, 'created test dataobj');

my $testuser = EPrints::Test::get_test_user( $repo );
ok( defined $testuser, 'loaded test user' );

my $rc = $testds->permit_action( "edit", $testuser );
ok( !$rc, 'action not allowed' );

print STDERR "TODO: a test with an authorised action\n";
