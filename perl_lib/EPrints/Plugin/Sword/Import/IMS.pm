package EPrints::Plugin::Sword::Import::IMS;

use strict;

use EPrints::Plugin::Sword::Import;
our @ISA = qw/ EPrints::Plugin::Sword::Import /;

our %SUPPORTED_MIME_TYPES =
(
        "application/zip" => 1,
);

our %UNPACK_MIME_TYPES =
(
        "application/zip" => "Sword::Unpack::Zip",
);

sub new
{
	my( $class, %params ) = @_;
	my $self = $class->SUPER::new( %params );
	$self->{name} = "SWORD Importer - IMS";
	$self->{visible} = "all";
	return $self;
}


sub input_file
{
	my ( $plugin, %opts ) = @_;

	my $session = $plugin->{session};

        my $mime = $opts{mime_type};
        my $file = $opts{file};
        my $NO_OP = $opts{no_op};

        # Let's find the XML file to import:
        unless( defined $SUPPORTED_MIME_TYPES{$mime} )
        {
                $plugin->add_verbose( "[ERROR] unknown MIME TYPE '$mime'." );
                $plugin->set_status_code( 415 );
                return undef;
        }

        my $unpacker = $UNPACK_MIME_TYPES{$mime};

        my $tmp_dir;

        if( defined $unpacker )
        {
                $tmp_dir = File::Temp->newdir( "swordXXXX", TMPDIR => 1 );

                if( !defined $tmp_dir )
                {
                        print STDERR "\n[SWORD-DEPOSIT] [INTERNAL-ERROR] Failed to create the temp directory!";
                        $plugin->add_verbose( "[INTERNAL ERROR] failed to create the temp directory." );
                        $plugin->set_status_code( 500 );
                        return undef;
                }

                my $files = $plugin->unpack_files( $unpacker, $file, $tmp_dir );
                unless(defined $files)
                {
                        $plugin->add_verbose( "[ERROR] failed to unpack the files." );
                        return undef;
                }

                my $candidates = $plugin->get_files_to_import( $files, "text/xml" );

                if(scalar(@$candidates) == 0)
                {
                        $plugin->add_verbose( "[ERROR] could not find the XML file." );
                        $plugin->set_status_code( 400 );
                        return undef;
                }
                elsif(scalar(@$candidates) > 1)
                {
                        $plugin->add_verbose( "[WARNING] there were more than one XML files in this archive. I am using the first one." );
                }

                $file = $$candidates[0];
        }


	my $dataset_id = $opts{dataset_id};
	my $owner_id = $opts{owner_id};
	my $depositor_id = $opts{depositor_id};
	
	my $fh;
        if( !open( $fh, $file ) )
        {
                $plugin->add_verbose( "ERROR: couldnt open the file: '$file' because '$!'" );
                $plugin->set_status_code( 500 );
                return undef;
        }

        my $unpack_dir;
        my $fntmp = $file;

        if( $fntmp =~ /^(.*)\/(.*)$/ )
        {
                $unpack_dir = $1;
                $fntmp = $2;
        }

	my $xml;
	while( my $d = <$fh> )
	{ 
		$xml .= $d 
	}

	my $dataset = $session->get_archive()->get_dataset( $dataset_id );
        
	if(!defined $dataset)
        {
                print STDERR "\n[SWORD-METS] [INTERNAL-ERROR] Failed to open the dataset '$dataset_id'.";
                $plugin->add_verbose( "ERROR: failed to open the dataset '$dataset_id'" );
                $plugin->set_status_code( 500 );
                return undef;
        }


	my $dom_doc;
	eval
	{
	        $dom_doc = EPrints::XML::parse_xml_string( $xml );
	};

	if($@ || !defined $dom_doc)
	{
                $plugin->add_verbose( "[ERROR] failed to parse the xml ($@)." );
                $plugin->set_status_code( 400 );
                return;
        }

	# Need to find the right sections in XML. We return 'undef' anytime a sub-section is not found.
	my $dom_top = $dom_doc->getDocumentElement;
	unless( defined $dom_top )
        {
                $plugin->set_status_code( 400 );
                $plugin->add_verbose( "[ERROR] failed to parse the xml: missing top element." );
                return;
        }

	my $metadata = ($dom_top->getElementsByTagName( "metadata" ))[0];
	unless( defined $metadata )
        {
                $plugin->set_status_code( 400 );
                $plugin->add_verbose( "[ERROR] failed to parse the xml: no <metadata> tag found." );
                return;
        }

	my $lom = ($metadata->getElementsByTagName( "lom" ))[0];
	unless( defined $lom )
        {
                $plugin->set_status_code( 400 );
                $plugin->add_verbose( "[ERROR] failed to parse the xml: no <lom> tag found." );
                return;
        }

	my $general = ($lom->getElementsByTagName( "general" ))[0];
	unless( defined $general )
        {
                $plugin->set_status_code( 400 );
                $plugin->add_verbose( "[ERROR] failed to parse the xml: no <general> tag found." );
                return;
        }

	my $title_wrap = ($general->getElementsByTagName( "title" ))[0];
	my $title;
	if( defined $title_wrap )
        {
		$title = ($title_wrap->getElementsByTagName( "langstring" ))[0];
        }

	my $epdata = {};

	if(defined $title)
	{
		$epdata->{title} = EPrints::XML::to_string( EPrints::XML::contents_of( $title ) );
	}

	my $abstract_wrap = ($general->getElementsByTagName( "description" ))[0];

	if(defined $abstract_wrap)
	{
		my $abstract = ($abstract_wrap->getElementsByTagName( "langstring" ))[0];
		if( defined $abstract )
		{
			$epdata->{abstract} = EPrints::XML::to_string( EPrints::XML::contents_of( $abstract ) );
		}
	}

	my $resources = ($dom_top->getElementsByTagName( "resources" ))[0];

	# looking for files to import...
	my @files;
	if( defined $resources )
	{
		foreach my $node ( $resources->getChildNodes )
		{
			next if( !EPrints::XML::is_dom( $node, "Element" ) );

			if($node->tagName eq 'resource')
			{
				my $file = ($node->getElementsByTagName( "file" ))[0];
				next unless defined $file;
				my $file_loc = $file->getAttribute( "href" );
				next unless defined $file_loc;
				push @files, $file_loc;
			}
		}
	}
	else
	{
		$plugin->add_verbose( "[WARNING] no <resources> tag found: no files will be imported." );
	}


	if( $NO_OP )
	{
		# should stop there!
                $plugin->add_verbose( "[OK] Plugin - import successful (but in No-Op mode)." );
                $plugin->set_status_code( 200 );
		return;
	}

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

	my $eprint = $dataset->create_object( $plugin->{session}, $epdata );

        unless(defined $eprint)
        {
                $plugin->set_status_code( 500 );
                $plugin->add_verbose( "[ERROR] failed to create the EPrint object." );
                return;
        }

	foreach my $file (@files)
	{
	        my %doc_data;
		$doc_data{_parent} = $eprint;
	        $doc_data{eprintid} = $eprint->get_id;

		# try to guess the MIME of the attached file:
               $doc_data{format} = $session->get_repository->call( 'guess_doc_type',
                                $session,
                                $unpack_dir."/".$file );

               if( $doc_data{format} eq 'other' )
               {
                        my $guess2 = EPrints::Sword::FileType::checktype_filename( $unpack_dir."/".$file );
                        $doc_data{format} = $guess2 unless( $guess2 eq 'application/octet-stream' );
               }

		$doc_data{main} = $file;

		local $session->get_repository->{config}->{enable_file_imports} = 1;

	        my %file_data;
	       	$file_data{filename} = $file;
	       	$file_data{url} = "file://$unpack_dir/$file";

        	$doc_data{files} = [ \%file_data ];

	        my $doc_dataset = $session->get_repository->get_dataset( "document" );

		my $document = EPrints::DataObj::Document->create_from_data( $session, \%doc_data, $doc_dataset );

	        if(!defined $document)
                {
                        $plugin->add_verbose( "[WARNING] Failed to create Document object." );
                }
	}

        if( $plugin->keep_deposited_file() )
        {
                if( $plugin->attach_deposited_file( $eprint, $opts{file}, $opts{mime_type} ) )
                {
                        $plugin->add_verbose( "[OK] attached deposited file." );
                }
                else
                {
                        $plugin->add_verbose( "[WARNING] failed to attach the deposited file." );
                }
        }

	$plugin->add_verbose( "[OK] EPrint object created." );

	return $eprint;
}


sub keep_deposited_file
{
        return 1;
}


1;






