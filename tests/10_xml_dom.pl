use strict;
use Test::More;

BEGIN {
	eval "require XML::DOM";
	if( $@ )
	{
		plan skip_all => "XML::DOM missing";
	}
	else
	{
		plan tests => 12;
	}
}

use EPrints::SystemSettings;
$EPrints::SystemSettings::conf->{enable_gdome} = 0;
$EPrints::SystemSettings::conf->{enable_libxml} = 0;
use_ok( "EPrints" );
use_ok( "EPrints::Test" );
use_ok( "EPrints::Test::XML" );
$EPrints::XML::CLASS = $EPrints::XML::CLASS; # suppress used-only-once warning
BAIL_OUT( "Didn't load expected XML library" )
	if $EPrints::XML::CLASS ne "EPrints::XML::DOM";

my $repo = EPrints::Test::get_test_repository();

&EPrints::Test::XML::xml_tests( $repo );

ok(1);

