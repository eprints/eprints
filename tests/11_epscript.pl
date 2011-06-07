use strict;
use Test::More tests => (14);

BEGIN { use_ok( "EPrints" ); }
BEGIN { use_ok( "EPrints::Test" ); }

my $session = EPrints::Test::get_test_session( 0 );
my $rv;

$rv = EPrints::Script::execute( "2", { session=>$session } );
ok( defined $rv, "EPScript returns a value" );
is( $rv->[0], 2, "EPScript returns correct value?" );
is( $rv->[1], "INTEGER", "EPScript returns correct value?" );

$rv = EPrints::Script::execute( '$foo{bar}', { session=>$session, foo=>{ bar=>23 } } );
is( $rv->[0], 23, "Value from a passed parameter" );

$rv = EPrints::Script::execute( '17+9', { session=>$session } );
is( $rv->[0], 26, "17+9: Basic Math" );

$rv = EPrints::Script::execute( '17-9', { session=>$session } );
is( $rv->[0], 8, "17-9: Basic Math" );

$rv = EPrints::Script::execute( '-42', { session=>$session } );
is( $rv->[0], -42, "-42: Unary minus" );

$rv = EPrints::Script::execute( '1--42', { session=>$session } );
is( $rv->[0], 43, "1--42: Unary minus again" );

$rv = EPrints::Script::execute( '-5*---(2+3)', { session=>$session } );
is( $rv->[0], 25, "-5*---(2+3): Unary minus with brackets and stacked uminus" );

$rv = EPrints::Script::execute( '$list.join(":")', { session=>$session, list=>[[1,2,3],"ARRAY"] } );
is( $rv->[0], "1:2:3", "join() function" );

my $mfield = $session->dataset( "user" )->field( "roles" );
$rv = EPrints::Script::execute( '$list.join(":")', { session=>$session, list=>[["a","b","c"],$mfield] } );
is( $rv->[0], "a:b:c", "join() function on a multiple field value" );

$session->terminate;

ok(1);

