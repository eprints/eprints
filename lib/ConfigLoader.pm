######################################################################
#
# cjg: NO INTERNATIONAL GUBBINS YET
#
######################################################################
#
#  __COPYRIGHT__
#
# Copyright 2000-2008 University of Southampton. All Rights Reserved.
# 
#  __LICENSE__
#
######################################################################

package EPrints::ConfigLoader;

use EPrintSite;

%EPrints::ConfigLoader::id2baseurl = ();

%EPrints::ConfigLoader::id2config = ();


sub get_config_by_url
{
	my( $url ) = @_;

	if( scalar %EPrints::ConfigLoader::id2baseurl == 0 )
	{
		my $config_file = $EPrintSite::base_path."/etc/sites.cfg";
		%EPrints::ConfigLoader::id2baseurl = ();
                open( SITES, $config_file ) ||
                        die "Can't open $config_file";
                while(<SITES>)
                {
                        chomp;
                        next unless( m/^([a-z][a-z0-9_]*)\s+([^\s]+)\s*$/ );
			$EPrints::ConfigLoader::id2baseurl{$1} = $2;
		}
		close SITES;
	}
	foreach( keys %EPrints::ConfigLoader::id2baseurl )
	{
		my $baseurl = $EPrints::ConfigLoader::id2baseurl{$_};
		if( substr( $url, 0, length($baseurl) ) eq $baseurl )
		{
			return get_config_by_id( $_ );
		}
	}
	return undef;
}


sub get_config_by_id
{
	my( $id ) = @_;
	
	if( defined $EPrints::ConfigLoader::id2config{$id} )
	{
		return $EPrints::ConfigLoader::id2config{$id};
	}
	require "EPrintSite/$id.pm";
	my $site = "EPrintSite::$id"->new();
	if( defined $site )
	{
		$EPrints::ConfigLoader::id2config{$id} = $site;
		return $site;
	}
	return undef;
}

1;
