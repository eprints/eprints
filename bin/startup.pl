use lib '/opt/eprints3/perl_lib';

######################################################################
#
#  __COPYRIGHT__
#
# Copyright 2000-2008 University of Southampton. All Rights Reserved.
# 
#  __LICENSE__
#
######################################################################

use Carp qw(verbose);
use EPrints;

use strict;

# Tell me more about warnings
$SIG{__WARN__} = \&Carp::cluck;

check_mod_perl();

load_archives();

print STDERR "EPrints archives loaded: ".join( ", ",  EPrints::Config::get_repository_ids() )."\n";

$EPrints::SystemSettings::loaded = 1;

sub check_mod_perl
{
	$ENV{MOD_PERL} or EPrints::abort( "not running under mod_perl!" );

	my $conf_v = $ENV{EPRINTS_APACHE};
	if( defined $conf_v )
	{
		my $av =  $EPrints::SystemSettings::conf->{apache};
		$av = "1" unless defined $av;

		my $mismatch = 0;
		$mismatch = 1 if( $av eq "2" && $conf_v ne "2" );
		$mismatch = 1 if( $av ne "2" && $conf_v ne "1" );
		if( $mismatch )
		{
			print STDERR <<END;

------------------------------------------------------------
According to a flag in the Apache configuration, the part
of it relating to EPrints was generated for running with 
Apache $conf_v but this version of EPrints is configured 
to use version $av of Apache.

You should probably check the "apache" parameter setting in
perl_lib/EPrints/SystemSettings.pm then run the script
generate_apacheconf, then try to start Apache again.
------------------------------------------------------------

END
			die "Apache version mismatch";
		}
	}
}

sub load_archives
{
	foreach( EPrints::Config::get_repository_ids() )
	{
		EPrints->get_repository( $_ );
	}
}

1;
