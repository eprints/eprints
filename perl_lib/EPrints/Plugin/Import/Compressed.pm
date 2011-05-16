=head1 NAME

EPrints::Plugin::Import::Compressed

=cut

package EPrints::Plugin::Import::Compressed;

use strict;

use EPrints::Plugin::Import::Archive;
use URI;

our @ISA = qw/ EPrints::Plugin::Import::Archive /;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new( %params );

	$self->{name} = "Unpack an archive (.zip or .tar.gz)";
	$self->{visible} = "all";
	$self->{advertise} = 1;
	$self->{produce} = [qw( dataobj/document dataobj/eprint )];
	$self->{accept} = [qw( application/zip application/x-gzip sword:http://purl.org/net/sword/package/SimpleZip )];

	return $self;
}

sub input_fh
{
	my( $self, %opts ) = @_;

	my $fh = $opts{fh};
	my $dataset = $opts{dataset};
	
	my $rc = 0;

	my( $type, $zipfile ) = $self->upload_archive($fh);

	my $repo = $self->{session};

	my $dir = $self->add_archive($zipfile, $type );

	my $epdata;

	if( $dataset->base_id eq "document" )
	{
		$epdata = $self->create_epdata_from_directory( $dir, 1 );
		warn($@), return if !defined $epdata;
	}
	elsif( $dataset->base_id eq "eprint" )
	{
		$epdata = $self->create_epdata_from_directory( $dir, 0 );
		warn($@), return if !defined $epdata;
		$epdata = {
			documents => $epdata,
		};
	}
	
	my @ids;

	my $dataobj = $self->epdata_to_dataobj( $dataset, $epdata );
	push @ids, $dataobj->id if defined $dataobj;

	return EPrints::List->new(
		session => $repo,
		dataset => $dataset,
		ids => \@ids );
}


######################################################################
=pod

=item $success = $doc->upload_archive( $filehandle, $filename, $archive_format )

Upload the contents of the given archive file. How to deal with the 
archive format is configured in SystemSettings. 

(In case the over-loading of the word "archive" is getting confusing, 
in this context we mean ".zip" or ".tar.gz" archive.)

=cut
######################################################################

sub upload_archive
{
	my( $self, $fh ) = @_;

	use bytes;

	binmode($fh);

	my $zipfile = File::Temp->new();
	binmode($zipfile);

	my $rc;
	my $lead;
	while($rc = sysread($fh, my $buffer, 4096))
	{
		$lead = $buffer if !defined $lead;
		syswrite($zipfile, $buffer);
	}
	EPrints->abort( "Error reading from file handle: $!" ) if !defined $rc;

	my $type = substr($lead,0,2) eq "PK" ? "zip" : "targz";

	return($type, $zipfile);
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

