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
	$self{ua}->env_proxy;

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

	my $tmpfile = File::Temp->new;

	my $r = $ua->get( $url,
		':content_file' => "$tmpfile",
	);
	$self->{err} = $r->request->uri . " " . $r->status_line, return if !$r->is_success;

	sysseek($tmpfile, 0, 0);

	$repo->plugin( "Import::XML",
		Handler => EPrints::CLIProcessor->new(
			epdata_to_dataobj => sub {
				push @epms, $repo->dataset( "epm" )->make_dataobj( $_[0] );
				return undef;
			},
		),
	)->input_fh(
		fh => $tmpfile,
		dataset => $repo->dataset( "epm" ),
	);

	if ( $ENV{"HTTPS"} )
	{
		for (my $e = 0; $e < @epms; $e = $e+1 )
		{
			$epms[$e]->{data}->{icon} =~ s/^http:/https:/g;
		}
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

	my $tmpfile = File::Temp->new;

	my $url = URI->new( $self->{base_url} );
	$url->path( $url->path . "id/eprint/" . $eprintid );

	my $req = HTTP::Request->new(
			GET => $url,
			[ Accept => 'application/vnd.eprints.epm+xml' ]
		);

	my $r = $self->{ua}->request( $req, "$tmpfile" );

	if( !$r->is_success )
	{
		$self->{err} = $r->request->uri . " " . $r->status_line;
		return;
	}
	if( $r->header( 'Content-Type' ) !~ m#^application/vnd\.eprints\.epm\+xml# )
	{
		$self->{err} = $r->request->uri . " expected application/vnd.eprints.epm+xml but got " . $r->header( 'Content-Type' );
		return;
	}

	sysseek($tmpfile, 0, 0);

	my $epdata = {};
	eval { EPrints::XML::event_parse($tmpfile, EPrints::DataObj::SAX::Handler->new(
		'EPrints::DataObj::EPM',
		$epdata = {},
		{
			dataset => $repo->dataset( "epm" ),
		},
	) ) };
	if( $@ )
	{
		$self->{err} = $@;
		return;
	}

	return $repo->dataset( "epm" )->make_dataobj( $epdata );
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

