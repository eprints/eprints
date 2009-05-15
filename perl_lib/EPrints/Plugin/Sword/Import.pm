package EPrints::Plugin::Sword::Import;

# This class must be over-ridden

use strict;
use EPrints::Plugin::Import;
our @ISA = qw/ EPrints::Plugin::Import /;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new( %params );

	$self->{name} = "SWORD Importer Interface";
	$self->{visible} = "all";

        $self->{verbose} = "";
        $self->{status_code} = 201;
	$self->{deposited_file_docid} = undef;

	return $self;
}


###        $opts{file} = $file;
###        $opts{mime_type} = $headers->{content_type};
###        $opts{dataset_id} = $target_collection;
###        $opts{owner_id} = $owner->get_id;
###        $opts{depositor_id} = $depositor->get_id if(defined $depositor);
###        $opts{no_op}   = is this a No-op?
###        $opts{verbose} = is this verbosed?
sub input_file
{
        my ( $plugin, %opts ) = @_;

        my $session = $plugin->{session};

	print STDERR "\nPlugin Sword::Import should be overridden";
	
	return;
}

sub unpack_files
{
        my ( $self, $plugin_id, $fn, $tmp_dir ) = @_;

        my $session = $self->{session};

        my $unpack_plugin = $session->plugin( $plugin_id );

        if(!defined $unpack_plugin)
        {
                print STDERR "\n[SWORD-DEPOSIT] [INTERNAL-ERROR] Failed to load plugin ".$plugin_id;
                $self->set_status_code( 500 );
				$self->add_verbose( "ERROR: failed to load plugin '$plugin_id'" );
                return undef;
        }

        my %opts;
        $opts{dir} = $tmp_dir."/content";
        $opts{filename} = $fn;

        my $files = $unpack_plugin->export( %opts );

        # test if the unpack plugin succeeded
        if( !defined $files )
        {
                $self->set_status_code( 400 );
				$self->add_verbose( "[ERROR] failed to decompress the archive." );
                return undef;
        }

        # add the full path to each files: (eg file.xml => /tmp/eprints12345/content/file.xml)
        for(my $i = 0; $i < scalar @$files; $i++)
        {
                next if $$files[$i] =~ /^\//;            # unless it already contains the full path
                $$files[$i] = $tmp_dir."/content/".$$files[$i];
        }

		$self->add_verbose( "[OK] archive decompressed." );

        return $files;
}


sub get_files_to_import
{
        my ( $self, $files, $mime_type ) = @_;

        my $session = $self->{session};

        my @candidates;

        # some useful transformations to the correct MIME type:
        if( $mime_type eq 'application/xml' )
        {
                $mime_type = 'text/xml';
        }
        elsif( $mime_type eq 'application/x-zip' )
        {
                $mime_type = 'application/zip';
        }
        elsif( $mime_type eq 'application/x-zip-compressed' )
        {
                $mime_type = 'application/zip';
        }

        foreach(@$files)
        {
                push @candidates, $_ if( $self->get_file_mime_type( $_ ) eq $mime_type )
        }

        return \@candidates;
}


sub get_file_mime_type
{
        my( $self, $filename ) = @_;

        return $self->{session}->get_repository->call( 'guess_doc_type',
                                $self->{session},
                                $filename );
}


sub set_status_code
{
	my( $self, $code ) = @_;

	$self->{status_code} = $code;

	return;
}


sub get_status_code
{
	my ( $self ) = @_;
	
	return $self->{status_code};
} 


sub add_verbose
{
	my ( $self, $text ) = @_;

	unless( defined $self->{verbose} )
	{
		$self->{verbose} = "";
	}

	$self->{verbose} .= $text."\n";

	return;
}

sub get_verbose
{
	my( $self ) = @_;

	return (defined $self->{verbose}) ? $self->{verbose} : "";
}


# this method should be overridden by custom plugins:
sub keep_deposited_file
{
	return 1;
}

sub attach_deposited_file
{
	my( $self, $eprint, $file, $mime ) = @_;

	my $fn = $file;
	if( $file =~ /^.*\/(.*)$/ )
	{
		$fn = $1;
	}

	my %doc_data;
	$doc_data{eprintid} = $eprint->get_id;
	$doc_data{format} =  $mime;
	$doc_data{formatdesc} = $self->{session}->phrase( "Sword/Deposit:document_formatdesc" );
	$doc_data{main} = $fn;

	my %file_data;
	$file_data{filename} = $fn;
	$file_data{data} = $file;

	$doc_data{files} = [ \%file_data ];

	my $doc_dataset = $self->{session}->get_repository->get_dataset( "document" );

	my $document = EPrints::DataObj::Document->create_from_data( $self->{session}, \%doc_data, $doc_dataset );

	return 0 unless( defined $document );

	$document->make_thumbnails;
	$eprint->generate_static;
	$self->set_deposited_file_docid( $document->get_id );

	return 1;
}

sub set_deposited_file_docid
{
	my ($self, $docid ) = @_;

	$self->{deposited_file_docid} = $docid if(defined $docid);
}

sub get_deposited_file_docid
{
	my ( $self ) = @_;

	return $self->{deposited_file_docid};
}

1;





