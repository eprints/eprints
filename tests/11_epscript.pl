use strict;
use Test::More tests => (32);

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

# Test one_of()
# Added by QUT, 20130522 for modified one_of() function

# Test original operation, i.e., items as an argument list
# Should match
$rv = EPrints::Script::execute( '$value.one_of("1","2","3")', { session=>$session, value=>["1","STRING"] } );
is( $rv->[0], "1", "one_of() function passed list of items, value matches on lower boundary item" );

$rv = EPrints::Script::execute( '$value.one_of("1","2","3")', { session=>$session, value=>["3","STRING"] } );
is( $rv->[0], "1", "one_of() function passed list of items, value matches on upper boundary item" );

$rv = EPrints::Script::execute( '$value.one_of("1")', { session=>$session, value=>["1","STRING"] } );
is( $rv->[0], "1", "one_of() function passed list with single item, value matches" );

$rv = EPrints::Script::execute( '$value.one_of(1,2,3)', { session=>$session, value=>[1,"INT"] } );
is( $rv->[0], "1", "one_of() function integer values, matching" );

$rv = EPrints::Script::execute( '$value.one_of("one","two","three")', { session=>$session, value=>["one","STRING"] } );
is( $rv->[0], "1", "one_of() function string values, matching" );


# Shouldn't match
$rv = EPrints::Script::execute( '$value.one_of("1","2","3")', { session=>$session, value=>["4","STRING"] } );
is( $rv->[0], "0", "one_of() function passed list of items, value doesn't match" );

$rv = EPrints::Script::execute( '$value.one_of("1")', { session=>$session, value=>["4","STRING"] } );
is( $rv->[0], "0", "one_of() function passed list with single item, value doesn't match" );

$rv = EPrints::Script::execute( '$value.one_of()', { session=>$session, value=>["4","STRING"] } );
is( $rv->[0], "0", "one_of() function passed no arguments, value doesn't match" );

$rv = EPrints::Script::execute( '$value.one_of(1,2,3)', { session=>$session, value=>[4,"INT"] } );
is( $rv->[0], "0", "one_of() function integer values, no match" );

$rv = EPrints::Script::execute( '$value.one_of("one","two","three")', { session=>$session, value=>["four","STRING"] } );
is( $rv->[0], "0", "one_of() function string values, no match" );


# Test array ref operation
# Should match
$rv = EPrints::Script::execute( '$value.one_of($array)', { session=>$session, value=>["1","STRING"], array=>[ ["1","2","3"], "ARRAY"] } );
is( $rv->[0], "1", "one_of() function passed array ref, value matches on lower boundary item" );

$rv = EPrints::Script::execute( '$value.one_of($array)', { session=>$session, value=>["3","STRING"], array=>[ ["1","2","3"], "ARRAY"] } );
is( $rv->[0], "1", "one_of() function passed array ref, value matches on upper boundary item" );

$rv = EPrints::Script::execute( '$value.one_of($array)', { session=>$session, value=>["1","STRING"], array=>[ ["1"], "ARRAY"] } );
is( $rv->[0], "1", "one_of() function passed array ref with single item, value matches" );

$rv = EPrints::Script::execute( '$value.one_of($array)', { session=>$session, value=>[1,"INT"], array=>[ [1,2,3], "ARRAY"] } );
is( $rv->[0], "1", "one_of() function passed array ref, integer values, value matches" );

# Shouldn't match
$rv = EPrints::Script::execute( '$value.one_of($array)', { session=>$session, value=>["4","STRING"], array=>[ ["1","2","3"], "ARRAY"] } );
is( $rv->[0], "0", "one_of() function passed array ref with multiple elements, value doesn't match" );

$rv = EPrints::Script::execute( '$value.one_of($array)', { session=>$session, value=>["4","STRING"], array=>[ ["1"], "ARRAY"] } );
is( $rv->[0], "0", "one_of() function passed array ref with single element, value doesn't match" );

$rv = EPrints::Script::execute( '$value.one_of($array)', { session=>$session, value=>["4","STRING"], array=>[ [], "ARRAY"] } );
is( $rv->[0], "0", "one_of() function passed empty array ref arg" );

$rv = EPrints::Script::execute( '$value.one_of($array)', { session=>$session, value=>[4,"INT"], array=>[ [1,2,3], "ARRAY"] } );
is( $rv->[0], "0", "one_of() function passed array ref, integer values, value matches" );

$session->terminate;

ok(1);

