use strict;
use Test::More tests => 20;

BEGIN { use_ok( "EPrints" ); }
BEGIN { use_ok( "EPrints::Test" ); }

EPrints::Test::mem_increase();

my $repo = EPrints::Test::get_test_repository( 0 );
#ok(defined $repo, 'opened an EPrints::Repository object (noisy, no_check_db)');

# suppresses error messages
$repo->{config}->{log} = sub {};

my $testds = EPrints::Test::get_test_dataset( $repo );
ok(defined $testds, 'loaded test dataset');

my $testobj = $testds->create_dataobj( {} );
ok(defined $testobj, 'created test dataobj');

ok(!$testobj->set_value( 'integer', 'text' ), 'setting text to integer' );
ok($testobj->set_value( 'integer', 123 ), 'setting integer to integer' );

ok(!$testobj->set_value( 'float', 'text' ), 'setting text to float' );
ok($testobj->set_value( 'float', 3.1415 ), 'setting float to float' );

ok(!$testobj->set_value( 'boolean', 'fail' ), 'setting text to boolean' );
ok($testobj->set_value( 'boolean', 'TRUE' ), 'setting boolean to boolean' );

#ok(!$testobj->set_value( 'set', 'text' ), 'setting invalid option to set' );
# fails:
ok($testobj->set_value( 'set', 'value1' ), 'setting valid option to set' );

ok(!$testobj->set_value( 'url', 'bla//blah' ), 'setting invalid url' );
ok($testobj->set_value( 'url', 'http://www.eprints.org' ), 'setting valid url' );

ok(!$testobj->set_value( 'email', '@meh' ), 'setting invalid email' );
ok($testobj->set_value( 'email', 'tests@eprints.org' ), 'setting valid url' );

ok($testobj->transfer( 'state3' ), 'transfering to valid state' );
ok(!$testobj->transfer( 'state2' ), 'transfering to invalid state' );

$testds->{"read-only"} = 1;

ok(!$testobj->set_value( 'text', 'text' ),'testing read-only property');

$testds->{"read-only"} = 0;

$testobj->commit;

ok(defined $testobj->revision, 'testing revision works' );
ok(defined $testobj->revision && $testobj->revision."" ne "1", 'testing revision incremented' );

