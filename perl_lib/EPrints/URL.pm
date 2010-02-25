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

=for Pod2Wiki

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

=item $url = $url->get( %opts [, $page ] )

Constructs a $url based on the current configuration and %opts. If $page is specified will return a URL to that page.

=over 4

=item scheme => "auto"

Link to same protocol as is active now (N/A to shell scripts).

=item scheme => "http"

Link to the non-secure location.

=item scheme => "https"

Link to the secure location.

=item host => 1

Create an absolute link (including host and port).

=item path => "auto"

Use the current path (N/A to shell scripts).

=item path => "static", path => "cgi", path => "images"

Link to the root of the static, cgi and images respectively.

=item query => 1

Create a self-referential link (i.e. include all parameters in the query part).

=back

=cut

sub get
{
	my( $self, @opts ) = @_;

	my $page = scalar(@opts) % 2 ? pop(@opts) : undef;
	my %opts = @opts;

	my $session = $self->{session};

	my $uri = URI->new("", "http");

	$opts{scheme} = "auto" unless defined $opts{scheme};
	$opts{host} = "" unless defined $opts{host};
	$opts{path} = "auto" unless defined $opts{path};

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
			my $port = $session->get_repository->get_conf( "secureport" ) || 443;
			$uri->port( $port ) if $port != 443;
		}
		else
		{
			$uri->scheme( "http" );
			$uri->host( $session->get_repository->get_conf( "host" ) );
			my $port = $session->get_repository->get_conf( "port" ) || 80;
			$uri->port( $port ) if $port != 80;
		}
	}

	# path
	if( $opts{path} eq "auto" )
	{
		if( !defined $session->get_request )
		{
			EPrints::abort( "Attempt to use CGI path in non-CGI environment" );
		}
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
	elsif( $opts{path} eq "images" )
	{
		$uri->path( $session->get_repository->get_conf( "$opts{scheme}_root" ) . "/style/images" );
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

	if( $opts{path} && defined($page) )
	{
		$uri->path( $uri->path . "/" . $page );
	}

	return "$uri";
}

######################################################################
=pod

=back

=cut
######################################################################

1; # For use/require success

