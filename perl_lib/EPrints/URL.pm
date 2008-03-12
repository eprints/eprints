######################################################################
#
# EPrints::URL
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

=pod

=head1 NAME

B<EPrints::URL> - URL utility methods

=head1 DESCRIPTION

This module contains utility methods for generating and getting URLs, relative paths etc.

=head1 SYNOPSIS

	use EPrints;

	my $base_url = $session->get_url->get(
		scheme => "auto",
		host => 1,
		path => "cgi",
		query => 0,
	);

=head1 METHODS

=over 4

=cut 

package EPrints::URL;

use warnings;
use strict;

use overload '""' => \&to_string;

sub new
{
	my( $class, %opts ) = @_;

	bless \%opts, $class;
}

sub to_string
{
	my( $self ) = @_;

	return $self->get( path => "auto" );
}

sub get
{
	my( $self, %opts ) = @_;

	my $session = $self->{session};

	my $uri = URI->new("", "http");

	$opts{scheme} ||= "auto";
	$opts{host} ||= "";
	$opts{path} ||= "";

	# scheme
	if( $opts{scheme} eq "auto" )
	{
		if( $session->get_secure )
		{
			$opts{scheme} = "https";
		}
		else
		{
			$opts{scheme} = "http";
		}
	}

	# host
	if( $opts{host} )
	{
		if( $opts{scheme} eq "https" )
		{
			$uri->scheme( "https" );
			$uri->host( $session->get_repository->get_conf( "securehost" ) );
			$uri->port( $session->get_repository->get_conf( "secureport" ) || 443 );
		}
		else
		{
			$uri->scheme( "http" );
			$uri->host( $session->get_repository->get_conf( "host" ) );
			$uri->port( $session->get_repository->get_conf( "port" ) || 80 );
		}
	}

	# path
	if( $opts{path} eq "auto" )
	{
		$uri->path( $session->get_request->uri );
	}
	elsif( $opts{path} eq "static" )
	{
		$uri->path( $session->get_repository->get_conf( "$opts{scheme}_root" ) );
	}
	elsif( $opts{path} eq "cgi" )
	{
		$uri->path( $session->get_repository->get_conf( "$opts{scheme}_cgiroot" ) );
	}

	# query
	if( $opts{path} && $opts{query} )
	{
		my @params;
		foreach my $param ($session->param)
		{
			my $value = $session->param( $param );
			push @params, $param => $value;
		}
		$uri->query_form( @params );
	}

	return "$uri";
}

######################################################################
=pod

=back

=cut
######################################################################

1; # For use/require success

