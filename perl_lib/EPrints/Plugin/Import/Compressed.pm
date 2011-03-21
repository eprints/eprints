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

	$self->{name} = "Import (zip)";
	$self->{visible} = "all";
	$self->{advertise} = 0;
	$self->{produce} = [qw( dataobj/document list/document )];
	$self->{accept} = [qw( application/zip application/x-gzip )];

	return $self;
}

sub input_fh
{
	my( $self, %opts ) = @_;

	my $fh = $opts{fh};
	
	my $dataobj = $opts{dataobj};
	
	my $rc = 0;

	my $zipfile = $self->upload_archive($fh);

	my $repo = $self->{session};

	my $cgi = $repo->get_query;

	my $mime_type = $repo->call('guess_doc_type',$repo,$fh );

	my $type = "";
	if ($mime_type eq "application/zip") {
		$type = "zip";
	} else {
		$type = "targz";
	}

	my $dir = $self->add_archive($zipfile, $type );

	my @docs;

	if ($dataobj->isa("EPrints::DataObj::Document") ) {
		$rc = $self->add_directory_to_document($dir,$dataobj);
		if ($rc != 0) {
			$rc = $self->set_main_file($dataobj);
			push @docs, $dataobj;
		}
		
	} elsif ($dataobj->isa("EPrints::DataObj::EPrint") ) {
		 @docs = $self->add_directory_to_eprint($dir,$dataobj);
	}
	
	unlink $dir;
	
	return undef if !scalar @docs;

	return EPrints::List->new(
		session => $repo,
		dataset => $repo->dataset( "document" ),
		ids => [map { $_->id } @docs] );

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

        while(sysread($fh, $_, 4096))
        {
                syswrite($zipfile, $_);
        }

	return $zipfile;

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

