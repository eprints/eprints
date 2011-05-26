=head1 NAME

EPrints::Plugin::Import::AtomMultipart

=cut

package EPrints::Plugin::Import::AtomMultipart;

use HTTP::Headers::Util;
use MIME::Multipart::Parser;

use strict;

our @ISA = qw/ EPrints::Plugin::Import /;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new( %params );

	$self->{name} = "Atom Multipart";
	$self->{visible} = "all";
	$self->{advertise} = 0;
	$self->{produce} = [qw( dataobj/eprint )];
	$self->{accept} = ['multipart/related; type="application/atom+xml"'];
	$self->{arguments}->{boundary} = undef;
	$self->{arguments}->{start} = undef;

	return $self;
}

sub input_fh
{
	my( $self, %opts ) = @_;

	my $fh = $opts{fh};
	my $dataset = $opts{dataset};
	my $boundary = delete $opts{boundary};
	my $start = delete $opts{start};
	local $self->{epdata};
	local $self->{_buffer} = "";
	
	my @parts = MIME::Multipart::Parser->new->parse( $fh, $boundary );

	shift @parts; # discard text-part

	foreach my $part (@parts)
	{
		my @headers = @{$part->{headers}};
		foreach my $i (0..$#headers)
		{
			$headers[$i] = $i % 2 ?
				[ HTTP::Headers::Util::split_header_words( $headers[$i] ) ]
				: lc($headers[$i])
		}
		$part->{headers} = { @headers };
	}

	if( $start )
	{
		for(my $i = 0; $i < @parts; ++$i)
		{
			if( $parts[$i]{headers}{'content-id'}[0][0] eq $start )
			{
				unshift @parts, splice(@parts,$i,1);
				last;
			}
		}
	}

	my $ct = eval { $parts[0]{headers}{'content-type'}[0][0] };
	if( !$ct || $ct ne 'application/atom+xml' )
	{
		$self->error( "Expected application/atom+xml as first part but got '$ct'" );
		return;
	}
	if( !$parts[1] )
	{
		$self->error( "Expected content part" );
		return;
	}

	my( $atom ) = $self->{repository}->get_plugins(
		type => "Import",
		can_accept => "application/atom+xml",
		can_produce => "dataobj/eprint",
	);
	if( !defined $atom )
	{
		$self->error( "No Atom import plugin available" );
		return;
	}

	$atom->{parse_only} = 1;
	$atom->{Handler} = $self;

	my $list = $atom->input_fh(
		%opts,
		fh => $parts[0]{tmpfile},
	);
	return if !defined $list;

	my $epdata = $self->{epdata};
	if( !defined $epdata )
	{
		$self->error( "Failed to get epdata from Import::Atom" );
		return;
	}

	# eval otherwise we'll need a lot of if-defineds
	my $mime_type = eval { $parts[1]{headers}{'content-type'}[0][0] };
	$mime_type = 'application/octet-stream' if !defined $ct;

	my $filename = eval {
		({ @{ $parts[1]{headers}{'content-disposition'}[0] } })->{filename}
	};
	$filename = 'main.bin' if !defined $filename;

	$epdata->{documents} ||= [];
	push @{$epdata->{documents}}, {
		format => $mime_type,
		main => $filename,
		files => [{
			filename => $filename,
			filesize => -s $parts[1]{tmpfile},
			mime_type => $mime_type,
			_content => $parts[1]{tmpfile},
		}],
	};

	my @ids;

	my $dataobj = $self->epdata_to_dataobj( $dataset, $epdata );
	push @ids, $dataobj->id if defined $dataobj;

	return EPrints::List->new(
		session => $self->{repository},
		dataset => $dataset,
		ids => \@ids );
}

sub parsed
{
	my( $self, $epdata ) = @_;

	$self->{epdata} = $epdata;
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

