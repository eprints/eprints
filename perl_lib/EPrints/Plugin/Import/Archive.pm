package EPrints::Plugin::Import::Archive;

use strict;

our @ISA = qw/ EPrints::Plugin::Import /;

$EPrints::Plugin::Import::DISABLE = 1;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new(%params);

	$self->{name} = "Base archive inport plugin: This should have been subclassed";
	$self->{visible} = "all";

	return $self;
}

sub input_fh
{
	my( $self, %opts ) = @_;

	my $fh = $opts{fh};

	

}


######################################################################
=pod

=item $success = $doc->add_archive( $file, $archive_format )

$file is the full path to an archive file, eg. zip or .tar.gz 

This function will add the contents of that archive to the document.

=cut
######################################################################

sub add_archive
{
        my( $self, $file, $archive_format ) = @_;

        my $tmpdir = File::Temp->newdir();

        # Do the extraction
        my $rc = $self->{session}->get_repository->exec(
                        $archive_format,
                        DIR => $tmpdir,
                        ARC => $file );
	unlink($file);	
	
	return( $tmpdir );
}

#####################################################################
=pod

=item $success = $plugin->set_main_file( $document) 

Set a main file for a document which may not have one.

by default this is index.html or the first file

=cut
#####################################################################

sub set_main_file
{
	my ($self, $doc) = @_;
	
	my $repo = $self->{session};

	if( !$doc->set_main( "index.html" ) && !$doc->set_main( "index.htm" ) )
        {
                my $files = $doc->value( "files" );
                if( @$files )
                {
                        my $file = $files->[0];
                        $doc->set_value( "main", $file->value( "filename" ) );
                }
        }
	
	if( $doc->is_set( "main" ) )
        {
                my $file = $doc->get_stored_file( $doc->value( "main" ) );
                $doc->set_value( "format", $repo->call( 'guess_doc_type',
			$repo,
                        $file->value( "filename" ) ) );
        }

        $doc->commit;
}







######################################################################
=pod

=item $success = $plugin->add_directory_to_document( $directory )

Upload the contents of $directory to this document. This will not set the main file.

This method expects $directory to have a trailing slash (/).

=cut
######################################################################

sub add_directory_to_document
{
        my( $self, $directory, $doc ) = @_;

        $directory =~ s/[\/\\]?$/\//;

        my $rc = 0;

        if( !-d $directory )
        {
                EPrints::abort( "Attempt to call upload_dir on a non-directory: $directory" );
        }

        File::Find::find( {
                no_chdir => 1,
                wanted => sub {
			return if -d $File::Find::name;
                        my $filepath = $File::Find::name;
                        my $filename = substr($filepath, length($directory));
                        open(my $filehandle, "<", $filepath);
                        unless( defined( $filehandle ) )
                        {
                                $rc = 0;
                                return;
                        }
                        my $stored = $doc->add_stored_file(
                                $filename,
                                $filehandle,
                                -s $filepath
                        );
                        $rc = defined $stored;
                },
        }, $directory );

        return $rc;
}

######################################################################
=pod

=item $success = $doc->add_directory_to_eprint( $directory )

Upload the contents of $directory to this eprint. This will create one document per file.

This method expects $directory to have a trailing slash (/).

=cut
######################################################################

sub add_directory_to_eprint
{
        my( $self, $directory, $eprint ) = @_;

	my $repo = $self->{session};

        $directory =~ s/[\/\\]?$/\//;

        my $rc = 0;
	my @docs;

        if( !-d $directory )
        {
                EPrints::abort( "Attempt to call upload_dir on a non-directory: $directory" );
        }

        File::Find::find( {
                no_chdir => 1,
                wanted => sub {
			return if -d $File::Find::name;
                        my $filepath = $File::Find::name;
                        my $filename = substr($filepath, length($directory));
                        open(my $filehandle, "<", $filepath);
                        unless( defined( $filehandle ) )
                        {
                                $rc = 0;
                                return;
                        }
			
			my $format = $repo->call( 'guess_doc_type', $repo, $filename );

			my $doc = $eprint->create_subdataobj( "documents", {
				format => $format,
				main => $filename,
			} );

                        my $stored = $doc->add_stored_file(
                                $filename,
                                $filehandle,
				-s $filepath
                        );

			if (defined $stored) {
				$doc->commit();
				push @docs, $doc;
			} else {
				$doc->remove();
			}
                        $rc = defined $stored;
                },
        }, $directory );

        return @docs;
}
1;
