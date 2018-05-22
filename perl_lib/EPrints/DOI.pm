######################################################################
#
# EPrints::DOI
#
######################################################################
#
#
######################################################################

=pod

=for Pod2Wiki

=head1 NAME

B<EPrints::DOI> - DOI utility methods

=head1 DESCRIPTION

This module contains utility methods for parsing and displaying DOIs.

=head1 SYNOPSIS

  use EPrints;
  
  my $doi = DOI->parse( "doi:10.1000/foo#bar" );
  print "Parsed $doi\n";
  # => "Parsed 10.1000/foo#bar"
  
  my $uri = $doi->to_uri;
  # => URI->new("https://doi.org/10.1000/foo%23bar")

=head1 METHODS

=over 4

=cut

package EPrints::DOI;

use URI::Escape;

use warnings;
use strict;

use overload
	'""' => \&_stringify,
	'.'  => \&_cat,
	'.=' => \&_cat0;

#
# Creates a new DOI object.
#
#   %opts = (
#     dir => $directory_code,
#     reg => $registrant_code,
#     dss => $doi_suffix_string,
#   )
#
# `dir` is always "10"
#
# A DOI looks like: "${dir}.${reg}/${dss}"
#
sub new
{
	my( $class, %opts ) = @_;

	my %self = ();

	my @keys = qw/ dir reg dss /;
	@self{ @keys } = @opts{ @keys };

	bless \%self, $class;
}

=item B<< $new_doi = $doi->clone >>

Creates a new DOI which is a copy of this one.

=cut

sub clone
{
	my( $self ) = @_;
	return ref($self)->new( %{$self} );
}

#
# Adds $rest to dss on a new DOI.
#
sub _cat
{
	my( $self, $rest ) = @_;
	return $self->clone->_cat0( $rest );
}

#
# Adds $rest to dss of this DOI.
#
sub _cat0
{
	my( $self, $rest ) = @_;

	$self->{dss} .= $rest;
	return $self;
}

=item B<< $doi = EPrints::DOI->parse( $string, %opts ) >>

Parses a DOI from a string.

Recognises the common forms:

=over 2

=item *

"doi:10.1000/foo#bar"

=item *

"https://doi.org/10.1000/foo%23bar"

=item *

"info:doi/10.1000/foo%23bar"

=back

etc.

Returns C<undef> if parsing fails.

Options:

=over 2

=item B<< test => 1 >>

Just tests that the string is parseable, and returns a boolean value.

=back

=cut

sub parse
{
	my( $class, $string, %opts ) = @_;

	my $doi = "$string";

	if( $doi =~ s!^https?://(?:(?:dx\.)?doi\.org|doi\.acm\.org|doi\.ieeecomputersociety\.org)/+(?:doi:)?!!i )
	{
		# It looks like a HTTP proxy URL.
		$doi = uri_unescape( $doi );
	}
	elsif( $doi =~ s!^info:doi/!!i )
	{
		# It looks like an info URI.
		$doi = uri_unescape( $doi );
	}
	else
	{
		# It's probably a DOI string.
		$doi =~ s!^doi:!!i;

		# final sanity check
		if( $doi =~ m!^10.[^/]+%2F!i )
		{
			$doi = uri_unescape( $doi );
		}
	}

	utf8::decode( $doi ) unless utf8::is_utf8( $doi );

	# ANSI/NISO Z39.84-2005
	# <http://www.niso.org/apps/group_public/download.php/6587/Syntax%20for%20the%20Digital%20Object%20Identifier.pdf>
	if( $doi =~ m!^(10)\.([^/]+)/(\p{Graph}(?:[^/]\p{Graph}*)?)! )
	{
		# FIXME: $2 and $3 may contain characters outside of /\p{Graph}/
		return 1 if $opts{test};
		return $class->new( dir=>$1, reg=>$2, dss=>$3 );
	}
	else
	{
		return 0 if $opts{test};
		#warn "'$string' is not a valid DOI string";
		return undef;
	}
}

=item B<< $string = $doi->to_string >>

Returns a simple string representation of this DOI.

For example "doi:10.1000/foo#bar"

=over 4

=item B<< noprefix => 1 >>

Disable the 'doi:' prefix (enabled by default).

=back


=cut

sub to_string
{
	my( $self, %opts ) = @_;
	return ( $opts{noprefix} ? '' : 'doi:' )
		. $self->{dir}
		. '.'
		. $self->{reg}
		. '/'
		. $self->{dss};
}

sub _stringify
{
	return shift->to_string;
}

#
# Returns a percent-encoded "dir.reg/dss" string.
#
sub _uri_path
{
	my( $self ) = @_;
	return $self->{dir}
		. '.'
		. uri_escape_utf8( $self->{reg} )
		. '/'
		. uri_escape_utf8( $self->{dss} );
}

#
# Returns an "info:doi/..." URI string.
#
sub _info_uri
{
	my( $self ) = @_;
	return 'info:doi/' . $self->_uri_path;
}

#
# Returns a "https://doi.org/..." URI string.
#
sub _http_url
{
	my( $self ) = @_;
	return 'https://doi.org/' . $self->_uri_path;
}

=item B<< $uri = $doi->to_uri( %opts ) >>

Returns a URI.

For example: "https://doi.org/10.1000/foo%23bar"

=over 4

=item B<< info => 1 >>

Returns an 'info:' URI instead of 'https:'.

=back

=cut

sub to_uri
{
	my( $self, %opts ) = @_;

	if( $opts{info} )
	{
		return URI->new( $self->_info_uri );
	}
	else
	{
		return URI->new( $self->_http_url );
	}
}

######################################################################
=pod

=back

=cut
######################################################################

1; # For use/require success


=head1 COPYRIGHT

=for COPYRIGHT BEGIN

Copyright 2017 Queensland University of Technology.

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

