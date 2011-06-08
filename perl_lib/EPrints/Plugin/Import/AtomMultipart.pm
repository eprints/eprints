=head1 NAME

EPrints::Plugin::Import::AtomMultipart

=cut

package EPrints::Plugin::Import::AtomMultipart;

use HTTP::Headers::Util;
use MIME::Multipart::Parser;
use MIME::Base64;
use MIME::QuotedPrint;

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
	
	if( !$boundary && $self->{repository}->get_online )
	{
		my $content_type = $self->{repository}->get_request->headers_in->{'Content-Type'};
		my( $mime_type, undef, @params ) = @{(HTTP::Headers::Util::split_header_words($content_type))[0]};
		my %params = @params;
		$boundary = $params{boundary};
	}
	if( !$boundary )
	{
		$self->error( "No boundary was found in the content-type" );
		return;
	}

	# read the content of the text-part
	my $fpos = 0;
	while(<$fh>)
	{
		$fpos += length($_);
		last if /^--$boundary/;
	}
	sysseek($fh,$fpos,0); # Multipart::Parser does sysread

	my @parts = MIME::Multipart::Parser->new->parse( $fh, $boundary );

	if( @parts != 2 )
	{
		$self->error( "Expected exactly 2 MIME parts but actually got ".@parts );
		return;
	}

	if( $start )
	{
		for(my $i = 0; $i < @parts; ++$i)
		{
			no warnings;
			if( $parts[$i]{headers}->header( 'Content-ID' ) eq $start )
			{
				unshift @parts, splice(@parts,$i,1);
				last;
			}
		}
	}

	my $ct = $parts[0]{headers}->header( 'Content-Type' );
	if( !$ct || $ct !~ m#^\s*application/atom\+xml\b# )
	{
		$self->error( "Expected application/atom+xml as first part but got '$ct'" );
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
	my $mime_type = $parts[1]{headers}->header( 'Content-Type' );
	$mime_type = 'application/octet-stream' if !defined $mime_type;
	$mime_type =~ s/\s*;.*$//;

	my $disposition = $parts[1]{headers}->header( 'Content-Disposition' ) || "";
	$disposition = (HTTP::Headers::Util::split_header_words( $disposition ))[0];
	$disposition = { @$disposition };
	my $filename = $disposition->{filename};
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

	my $dataobj = $self->SUPER::epdata_to_dataobj( $dataset, $epdata );
	push @ids, $dataobj->id if defined $dataobj;

	return EPrints::List->new(
		session => $self->{repository},
		dataset => $dataset,
		ids => \@ids );
}

sub epdata_to_dataobj
{
	my( $self, $epdata ) = @_;

	$self->{epdata} = $epdata;

	return undef;
}

sub message
{
	shift->handler->message( @_ );
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

