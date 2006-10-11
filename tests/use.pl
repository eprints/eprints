#!/usr/bin/perl -w  

use TestLib;
use Test::More tests => 2;


testmodule('EPrints' );

SKIP: {
	skip( "Don't have mod_perl v1 tests yet",1 );

	testmodule('EPrints::RequestWrapper');
      }

sub testmodule
{
	my( $module ) = @_;
	my $code = "use TestLib; use $module; print \"1\";";
	my $exec = "/usr/bin/perl -w -e '$code'";
	$rc = `$exec`;
	ok($rc, $module);
}

# not yet doing MetaField/x*
# not yet doing bundled modules
