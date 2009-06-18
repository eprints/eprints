package EPrints::Plugin::Sword::Import::GenericFile;

use strict;

use EPrints::Plugin::Sword::Import;
our @ISA = qw/ EPrints::Plugin::Sword::Import /;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new( %params );
	$self->{name} = "SWORD Importer - Generic";
	$self->{visible} = "all";
	return $self;
}


#
#        $opts{file} = $file;
#        $opts{mime_type} = $headers->{content_type};
#        $opts{dataset_id} = $target_collection;
#        $opts{owner_id} = $owner->get_id;
#        $opts{depositor_id} = $depositor->get_id if(defined $depositor);
#	 $opts{no_op}	= is this a No-op?
#	 $opts{verbose} = is this verbosed?
sub input_file
{
	my ( $plugin, %opts ) = @_;

	my $session = $plugin->{session};

	my $file = $opts{file};

	my $dataset_id = $opts{dataset_id};
	my $owner_id = $opts{owner_id};
	my $depositor_id = $opts{depositor_id};

	# if $NO_OP (No Operation) is set then we don't really need to import
	my $NO_OP = $opts{no_op};
	my $VERBOSE = $opts{verbose};

	my $dataset = $session->get_archive()->get_dataset( $dataset_id );

	if(!defined $dataset)
        {
		$plugin->add_verbose( "[INTERNAL ERROR] Failed to open target dataset '$dataset_id'." );
		$plugin->set_status_code( 500 );
                print STDERR "\n[Sword::Import::GenericFile] [INTERNAL-ERROR] Failed to open the dataset '$dataset_id'.";
                return;
        }

	# This is all we can try to do in No-OP mode in this plugin so time to leave!
	if( $NO_OP )
	{
		$plugin->add_verbose( "[OK] No-Op mode: would have created a new resource otherwise." );
		$plugin->set_status_code( 200 );
		return;
	}

	my $epdata = {};
	if(defined $depositor_id)
	{
		$epdata->{userid} = $owner_id;
		$epdata->{sword_depositor} = $depositor_id;
	}
	else
	{
		$epdata->{userid} = $owner_id;
	}
	
	$epdata->{eprint_status} = $dataset_id;

	# minimal amount of metadata!
	my $eprint = $dataset->create_object( $plugin->{session}, $epdata );
		
	unless( defined $eprint )
	{
		$plugin->add_verbose( "[INTERNAL ERROR] Failed to create a new EPrint object.\n" );
		$plugin->set_status_code( 500 );
                print STDERR "\n[Sword::Import::GenericFile] [INTERNAL-ERROR] Failed to create a new EPrint object.";
                return;
	}
	
	my $fn = $file;

	if( $file =~ /^.*\/(.*)$/ )
	{
		$fn = $1;
	}

	my %doc_data;
	$doc_data{_parent} = $eprint;
	$doc_data{eprintid} = $eprint->get_id;
	if( defined $opts{mime_type} && $opts{mime} ne 'application/octet-stream' )
	{
		$doc_data{format} = $opts{mime_type};
	}
	else
	{
		$doc_data{format} = $session->get_repository->call( "guess_doc_type", $session, $file );
	}

	local $session->get_repository->{config}->{enable_file_imports} = 1;

	$doc_data{main} = $fn;

	my %file_data;
	
	$file_data{filename} = $fn;
	$file_data{url} = "file://$file";	

	$doc_data{files} = [ \%file_data ];

	my $doc_dataset = $session->get_repository->get_dataset( "document" );

	my $document = EPrints::DataObj::Document->create_from_data( $session, \%doc_data, $doc_dataset );

	if(!defined $document)
	{
		$eprint->remove();
		$eprint->commit();
		print STDERR "\n[Sword::Import::GenericFile] [ERROR] Failed to add the attached file to the eprint.";
		$plugin->set_status_code( 500 );
		$plugin->add_verbose( "[INTERNAL ERROR] Failed to create a new Document object." );
                return;
	}
	else
	{
		$document->make_thumbnails();
	}

	if( $fn =~ /\.docx|pptx$/ )
	{
		my $conv_plugin = $session->plugin( "Convert::OpenXML" );
		if( $conv_plugin )
		{
			my @new_docs = $conv_plugin->convert( $eprint, $document, 'both' );
			print STDERR "\nnew docs: ".join(",",@new_docs);
		}
	}

	$eprint->generate_static();

	$plugin->set_deposited_file_docid( $document->get_id );

	$plugin->add_verbose( "[OK] Import plugin created the resource." );

	return $eprint;
}

sub keep_deposited_file
{
	return 0;
}

1;
