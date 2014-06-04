######################################################################
#
# EPrints::URL
#
######################################################################
#
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

Link to the secure location (or http if C<securehost> isn't defined).

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
		if( $session->is_secure )
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
		if( $opts{scheme} eq "https" && EPrints::Utils::is_set( $session->config( "securehost" ) ) )
		{
			$uri->scheme( "https" );
			$uri->host( $session->config( "securehost" ) );
			my $port = $session->config( "secureport" ) || 443;
			$uri->port( $port ) if $port != 443;
		}
		else
		{
			$uri->scheme( "http" );
			$uri->host( $session->config( "host" ) );
			my $port = $session->config( "port" ) || 80;
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
		$uri->path( $session->config( "$opts{scheme}_root" ) );
	}
	elsif( $opts{path} eq "cgi" )
	{
		$uri->path( $session->config( "$opts{scheme}_cgiroot" ) );
	}
	elsif( $opts{path} eq "images" )
	{
		$uri->path( $session->config( "$opts{scheme}_root" ) . "/style/images" );
	}

	# query
	if( $opts{path} && $opts{query} )
	{
		my @params;
		foreach my $param ($session->param)
		{
			foreach my $value ($session->param( $param ))
			{
				next if ref($value); # e.g. file handle
				push @params, $param => Encode::encode_utf8( $value );
			}
		}
		$uri->query_form( @params );
	}

	if( $opts{path} && defined($page) )
	{
		$uri->path( $uri->path . "/" . $page );
	}

	return $uri;
}

######################################################################
=pod

=back

=cut
######################################################################

1; # For use/require success


=head1 COPYRIGHT

=for COPYRIGHT BEGIN

Copyright 2000-2011 University of Southampton.

=for COPYRIGHT END

=for LICENSE BEGIN

This file is part of EPrints L<http://www.eprints.org/>.

EPrints is free software: you can redistribute it and/or modify it
under the terms of the GNU Lesser General Public License as published
by the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

EPrints is distributed in the hope that it will be useful, but WITHOUT
ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser General Public
License for more details.

You should have received a copy of the GNU Lesser General Public
License along with EPrints.  If not, see L<http://www.gnu.org/licenses/>.

=for LICENSE END

