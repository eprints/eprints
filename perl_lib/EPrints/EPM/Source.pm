=head1 NAME

EPrints::EPM::Source - utility for talking to EPM sources

=cut

package EPrints::EPM::Source;

use strict;

=item $source = EPrints::EPM::Source->new( %opts )

	repository
	base_url

=cut

sub new
{
	my( $class, %self ) = @_;

	$self{ua} = LWP::UserAgent->new;

	return bless \%self, $class;
}

=item EPrints::EPM::Source->map( $repo, sub { ... } )

=cut

sub map
{
	my( $class, $repo, $f ) = @_;

	my $sources = $repo->config( "epm", "sources" );
	$sources = [
		{ name => "EPrints Bazaar", base_url => "http://bazaar.eprints.org/" }
	] if !defined $sources;

	foreach my $source (@$sources)
	{
		&$f( $repo, $class->new(
			%$source,
			repository => $repo,
		) );
	}
}

=item $epms = $source->query( $q )

Queries the source for EPMs. $q may be blank.

Returns undef if something went wrong.

=cut

sub query
{
	my( $self, $q ) = @_;

	my $repo = $self->{repository};

	my $base_url = $self->{base_url};
	my $ua = $self->{ua};

	my @epms;

	my $url = URI->new( $base_url );
	$url->path( $url->path . "cgi/search" );
	$url->query_form( q => $q, output => "EPMI" );

	my $r = $ua->get( $url );
	$self->{err} = $r->request->uri . " " . $r->status_line, return if !$r->is_success;

	my $xml = eval { $repo->xml->parse_string( $r->content ) };
	$self->{err} = $@, return if $@;

	foreach my $epm ($xml->documentElement->getElementsByTagName( "epm" ))
	{
		my $dataobj = $repo->dataset( "epm" )->dataobj_class->new_from_xml(
			$repo,
			$epm->toString()
		);
		push @epms, $dataobj if defined $dataobj;
	}

	return \@epms;
}

=item $epm = $source->epm_by_eprintid( $eprintid )

Retrieves an installable EPM from the source with $eprintid.

=cut

sub epm_by_eprintid
{
	my( $self, $eprintid ) = @_;

	my $repo = $self->{repository};

	my $url = URI->new( $self->{base_url} );
	$url->path( $url->path . "id/eprint/" . $eprintid );

	my $r = $self->{ua}->request( HTTP::Request->new(
		GET => $url,
		[ Accept => 'application/vnd.eprints.epm+xml' ]
		) );
	$self->{err} = $r->request->uri . " " . $r->status_line, return
		if !$r->is_success;
	if( $r->header( 'Content-Type' ) !~ m#^application/vnd\.eprints\.epm\+xml# )
	{
		$self->{err} = $r->request->uri . " expected application/vnd.eprints.epm+xml but got " . $r->header( 'Content-Type' );
		return;
	}

	my $xml = eval { $repo->xml->parse_string( $r->content ) };
	$self->{err} = $@, return if $@;

	return EPrints::DataObj::EPM->new_from_xml( $self->{repository},
		$xml->toString()
	);
}

1;

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

