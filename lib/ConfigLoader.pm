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

my %id2config = ();

sub get_config_by_url
{
	my( $url ) = @_;
	$hostpath = $url;
	$hostpath =~ s#^[a-z]+://##;
	return get_config_by_host_and_path( $hostpath );
}

sub get_config_by_host_and_path
{
	my( $hostpath ) = @_;

	foreach( keys %EPrintSite::sites )
	{
		if( substr( $hostpath, 0, length($_) ) eq $_ )
		{
			return get_config_by_id( $EPrintSite::sites{$_} );
		}
	}
	return undef;
}


sub get_config_by_id
{
	my( $id ) = @_;

	print STDERR "Loading: $id\n";
	
	if( defined $id2config{$id} )
	{
		return $id2config{$id};
	}
	require "EPrintSite/$id.pm";
	my $site = "EPrintSite::$id"->new();
	if( defined $site )
	{
		$id2config{$id} = $site;
		return $site;
	}
	return undef;
}

1;
