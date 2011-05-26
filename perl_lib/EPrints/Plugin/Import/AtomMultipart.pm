=head1 NAME

EPrints::Plugin::Import::AtomMultipart

=cut

package EPrints::Plugin::Import::AtomMultipart;

use HTTP::Headers::Util;
use MIME::Parser;

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
	$self->{accept} = [qw( multipart/related )];
	$self->{arguments}->{boundary} = undef;

	return $self;
}

sub read_line
{
	my( $self, $fh ) = @_;

	use bytes;
	local $_;

	for($self->{_buffer})
	{
		while( length($_) < 8092 )
		{
			last if !sysread($fh, $_, 8092, length($_));
		}

		$_ =~ s#^((?:[^\n]*\n)|.+)##s;

		return length($1) ? $1 : undef;
	}
}

sub read_part
{
	my( $self, $fh, $boundary ) = @_;

	local $_;

	my @headers;
	while(defined($_ = $self->read_line($fh)))
	{
		s/\r?\n$//;
		last if $_ eq "";
		$headers[$#headers][1] .= $_, next if s/^ //;
		push @headers, [split ':', $_, 2];
	}
	return if !defined $_;
	for(@headers)
	{
		$_->[0] = lc $_->[0];
		$_->[1] = [ HTTP::Headers::Util::split_header_words( $_->[1] ) ];
	}
	my %headers = map { @$_ } @headers;

	my $tmpfile = File::Temp->new;

	my $le = "";
	while(defined($_ = $self->read_line($fh)))
	{
		last if /^--$boundary/;
		syswrite($tmpfile, $le);
		s/(\r?\n)$//;
		$le = $1;
		syswrite($tmpfile, $_);
	}

	seek($tmpfile,0,0);

	return {
		headers => \%headers,
		_content => $tmpfile,
	};
}

sub input_fh
{
	my( $self, %opts ) = @_;

	my $fh = $opts{fh};
	my $dataset = $opts{dataset};
	my $boundary = delete $opts{boundary};
	local $self->{epdata};
	local $self->{_buffer} = "";
	
	my @parts;
	while(my $part = $self->read_part($fh, $boundary))
	{
		push @parts, $part;
	}

	shift @parts; # discard text-part

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
		fh => $parts[0]{_content},
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
			filesize => -s $parts[1]{_content},
			mime_type => $mime_type,
			_content => $parts[1]{_content},
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

