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

package EPrints::Site;

use EPrints::Site::General;

my %ID2SITE = ();

sub get_site_by_url
{
	my( $url ) = @_;
	$hostpath = $url;
	$hostpath =~ s#^[a-z]+://##;
	return get_site_by_host_and_path( $hostpath );
}

sub get_site_by_host_and_path
{
	my( $hostpath ) = @_;

	foreach( keys %EPrints::Site::General::sites )
	{
		if( substr( $hostpath, 0, length($_) ) eq $_ )
		{
			return get_site_by_id( $EPrints::Site::General::sites{$_} );
		}
	}
	return undef;
}


sub get_site_by_id
{
	my( $id ) = @_;

	print STDERR "Loading: $id\n";
	
	if( defined $ID2SITE{$id} )
	{
		return $ID2SITE{$id};
	}
	require "EPrints/Site/$id.pm";
	my $site = "EPrints::Site::$id"->new();
	if( defined $site )
	{
		$ID2SITE{$id} = $site;
		return $site;
	}
	return undef;
}

1;
