use strict;
use Test::More;

BEGIN {
	eval "require XML::LibXML;";
	if( $@ || XML::LibXML->VERSION lt v1.66 )
	{
		plan skip_all => "XML::LibXML 1.66+ missing";
	}
	else
	{
		plan tests => 12;
	}
}

use EPrints::SystemSettings;
$EPrints::SystemSettings::conf->{enable_gdome} = 0;
$EPrints::SystemSettings::conf->{enable_libxml} = 1;
use_ok( "EPrints" );
use_ok( "EPrints::Test" );
use_ok( "EPrints::Test::XML" );
$EPrints::XML::CLASS = $EPrints::XML::CLASS; # suppress used-only-once warning
BAIL_OUT( "Didn't load expected XML library" )
	if $EPrints::XML::CLASS ne "EPrints::XML::LibXML";

my $repo = EPrints::Test::get_test_repository();

&EPrints::Test::XML::xml_tests( $repo );

ok(1);
