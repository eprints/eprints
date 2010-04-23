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
	$self->{produce} = [ 'dataobj/document', 'list/document' ];
	$self->{mime_type} = [ 'application/zip', 'application/x-gzip' ];

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
