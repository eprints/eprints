package EPrints::Plugin::Sword::Import::METS;

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
	$self->{name} = "SWORD Importer - METS/EPDCX (alpha)";
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

        my $dir = $opts{dir};
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
                $tmp_dir = EPrints::TempDir->new( "swordXXX", UNLINK => 1 );

                if( !defined $tmp_dir )
                {
                        print STDERR "\n[SWORD-DEPOSIT] [INTERNAL-ERROR] Failed to create the temp directory!";
                        $plugin->add_verbose( "[ERROR] failed to create the temp directory." );
			$plugin->set_status_code( 500 );
                        return undef;
                }

                my $files = $plugin->unpack_files( $unpacker, $file, $tmp_dir );
                unless(defined $files)
                {
                        $plugin->add_verbose( "[ERROR] failed to unpack the files" );
                        return undef;
                }

                my $candidates = $plugin->get_files_to_import( $files, "text/xml" );

                if(scalar(@$candidates) == 0)
                {
                        $plugin->add_verbose( "[ERROR] could not find the XML file" );
			$plugin->set_status_code( 400 );
                        return undef;
                }
                elsif(scalar(@$candidates) > 1)
                {
                        $plugin->add_verbose( "[WARNING] there were more than one XML file in this archive. I am using the first one" );
                }

                $file = $$candidates[0];
        }

       
        my $dataset_id = $opts{dataset_id};
        my $owner_id = $opts{owner_id};
        my $depositor_id = $opts{depositor_id};

	my $fh;
	if( !open( $fh, $file ) )
	{
		$plugin->add_verbose( "[ERROR] couldnt open the file: '$file' because '$!'" );
		$plugin->set_status_code( 500 );
		return;
	}

	my $unpack_dir;
	my $fntmp;

	$fntmp = $file;

	if( $fntmp =~ /^(.*)\/(.*)$/ )
	{
		$unpack_dir = $1;
		$fntmp = $2;
	}
	
	# needs to read the xml from the file:
	my $xml;
	while( my $d = <$fh> )
	{ 
		$xml .= $d 
	}
	close $fh;

	my $dataset = $session->get_archive()->get_dataset( $dataset_id );

	if(!defined $dataset)
	{
		print STDERR "\n[SWORD-METS] [INTERNAL-ERROR] Failed to open the dataset '$dataset_id'.";
		$plugin->add_verbose( "[INTERNAL ERROR] failed to open the dataset '$dataset_id'" );
		$plugin->set_status_code( 500 );
		return;
	}

        my $dom_doc;
        eval
        {
                $dom_doc = EPrints::XML::parse_xml_string( $xml );
        };

        if($@ || !defined $dom_doc)
        {
		$plugin->add_verbose( "[ERROR] failed to parse the xml: '$@'" );
		$plugin->set_status_code( 400 );
                return;
        }

	if( !defined $dom_doc )
	{
		$plugin->{status_code} = 400;
		$plugin->add_verbose( "[ERROR] failed to parse the xml." );
		return;
	}

        my $dom_top = $dom_doc->getDocumentElement;

	if( lc $dom_top->tagName ne 'mets' )
	{
		$plugin->set_status_code( 400 );
		$plugin->add_verbose( "[ERROR] failed to parse the xml: no <mets> tag found." );
		return;
	}

	# METS Headers (ignored)
	my $mets_hdr = ($dom_top->getElementsByTagName( "metsHdr" ))[0];

	# METS Descriptive Metadata (main section for us)

	# need to loop on dmdSec:
	my @dmd_sections = $dom_top->getElementsByTagName( "dmdSec" );

	my $md_wrap;
	my $found_wrapper = 0;
	foreach my $dmd_sec (@dmd_sections)
	{
		# need to extract xmlData from here
		$md_wrap = ($dmd_sec->getElementsByTagName( "mdWrap" ))[0];

		next if( !defined $md_wrap );

		next if(!( lc $md_wrap->getAttribute( "MDTYPE" ) eq 'other' && defined $md_wrap->getAttribute( "OTHERMDTYPE" ) && lc $md_wrap->getAttribute( "OTHERMDTYPE" ) eq 'epdcx' ));
	
		$found_wrapper = 1;
		
		last;
	}

	unless( $found_wrapper )
	{
		$plugin->set_status_code( 400 );
		$plugin->add_verbose( "[ERROR] failed to parse the xml: could not find epdcx <mdWrap> section." );
		return;
	}

	my $xml_data = ($md_wrap->getElementsByTagName( "xmlData" ))[0];

	if(!defined $xml_data)
	{
		$plugin->set_status_code( 400 );
		$plugin->add_verbose( "[ERROR] failed to parse the xml: no <xmlData> tag found." );
		return;
	}
	
	my $epdata = $plugin->parse_epdcx_xml_data( $xml_data );

	return unless( defined $epdata );

	# File Section which will contain optional info about files to import:
	my @files;
	foreach my $file_sec ( $dom_top->getElementsByTagName( "fileSec" ) )
	{
	        my $file_grp = ($file_sec->getElementsByTagName( "fileGrp" ))[0];

        	$file_sec = $file_grp if( defined $file_grp );	# this is because the <fileGrp> tag is optional

		foreach my $file_div ($file_sec->getElementsByTagName( "file" ))
		{
			my $file_loc = ($file_div->getElementsByTagName( "FLocat" ))[0];
			if(defined $file_loc)
			{		# yeepee we have a file (maybe)

				my $fn = $file_loc->getAttribute( "href" );

				unless( defined $fn )
				{
					# to accommodate the gdome XML library:
					$fn = $file_loc->getAttribute( "xlink:href" );
				}

				next unless( defined $fn );

				next if $fn =~ /^http/;	# wget those files?

				push @files, $fn;				

			}
		}
	}

	unless( scalar(@files) )
	{
		$plugin->add_verbose( "[WARNING] no <fileSec> tag found: no files will be imported." );
	}

	if( $NO_OP )
	{
		# need to send 200 Successful (the deposit handler will generate the XML response)
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
	        $doc_data{eprintid} = $eprint->get_id;
 
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


sub parse_epdcx_xml_data
{
	my ( $plugin, $xml ) = @_;

	my $set = ($xml->getElementsByTagName( "descriptionSet" ))[0];

	unless( defined $set )
	{
		$plugin->set_status_code( 400 );
		$plugin->add_verbose( "ERROR: no <descriptionSet> tag found." );
		return;
	}

	my $epdata = {};

	foreach my $desc ($set->getElementsByTagName( "description" ))
	{

		foreach my $stat ($desc->getElementsByTagName( "statement" ))
		{
			my ($field, $value) = _parse_statement( $stat );

			if( defined $field )
			{
				if( $field eq 'creator' )
				{

					$value = clean_text( $value );

					if($value =~ /(\w+)\,\s?(.*)$/)
					{
						push @{$epdata->{creators_name}}, {family => $1, given=>$2};
					}
					else
					{
						push @{$epdata->{creators_name}}, {family => $value};
					}
				}
				else
				{
					$epdata->{$field} = $value;
				}

			}

		}
	}

	return $epdata;
}



sub _parse_statement
{
	my ( $stat ) = @_;

	my $property = $stat->getAttribute( "propertyURI" );

	unless( defined $property )
	{
		$property = $stat->getAttribute( "epdcx:propertyURI" );
	}

	if( $property eq 'http://purl.org/dc/elements/1.1/type' )
	{
		if( $stat->getAttribute( "valueURI" ) =~ /type\/(.*)$/ )
		{	# then $1 = type

# reference for these mappings is:
# "http://www.ukoln.ac.uk/repositories/digirep/index/Eprints_Type_Vocabulary_Encoding_Scheme"

			my $type = $1;	# no need to clean_text( $1 ) here

			if( $type eq 'JournalArticle' || $type eq 'JournalItem' || $type eq 'SubmittedJournalArticle' || $type eq 'WorkingPaper' )
			{
				$type = 'article';
			}
			elsif( $type eq 'Book' )
			{
				$type = 'book';
			}
		        elsif( $type eq 'BookItem' )
                        {
                                $type = 'book_section';
                        }
			elsif( $type eq 'ConferenceItem' || $type eq 'ConferencePoster' || $type eq 'ConferencePaper' )
                        {
                                $type = 'conference_item';
                        }
			elsif( $type eq 'Patent' )
			{
				$type = 'patent';
			}
			elsif( $type eq 'Report' )
			{
				$type = 'monograph';	# I think?
			}
			elsif( $type eq 'Thesis' )
			{
				$type = 'thesis';
			}
			else
			{
				return;		# problem there! But the user can still correct this piece of data...
			}


			return ( "type", $type );
		}
		return;
		
	}
	elsif( $property eq 'http://purl.org/dc/elements/1.1/title' )
	{
		my $value = ($stat->getElementsByTagName( "valueString"  ))[0];
		my $title = EPrints::XML::to_string( EPrints::XML::contents_of( $value ) );
		return ( "title", clean_text($title) );

	}
	elsif( $property eq 'http://purl.org/dc/terms/abstract' )
	{
                my $value = ($stat->getElementsByTagName( "valueString"  ))[0];
                my $abstract = EPrints::XML::to_string( EPrints::XML::contents_of( $value ) );
                return ( "abstract", clean_text($abstract) );
	}
        elsif( $property eq 'http://purl.org/dc/elements/1.1/creator' )
        {
                my $value = ($stat->getElementsByTagName( "valueString"  ))[0];
                my $name = EPrints::XML::to_string( EPrints::XML::contents_of( $value ) );
                return ( "creator", clean_text($name) );
        }
        elsif( $property eq 'http://purl.org/dc/elements/1.1/identifier' )
        {
                my $value = ($stat->getElementsByTagName( "valueString"  ))[0];
                my $id = EPrints::XML::to_string( EPrints::XML::contents_of( $value ) );
                return ( "id_number", clean_text($id) );
        }

        elsif( $property eq 'http://purl.org/eprint/terms/status' )
        {
		if( $stat->getAttribute( "valueURI" ) =~ /status\/(.*)$/ )
		{
			my $status = $1;
			if( $status eq 'PeerReviewed' )
			{
				$status = 'TRUE';
			}
			elsif( $status eq 'NonPeerReviewed' )
			{
				$status = 'FALSE';
			}
			else { return; }

			return ( 'refereed', $status );	# is this the proper field?

		}

		return;

        }

	elsif( $property eq 'http://purl.org/dc/elements/1.1/language' )
	{
		# LANGUAGE (not parsed)
	}
	
	elsif( $property eq 'http://purl.org/dc/terms/available' )
	{
		# DATE OF AVAILABILITY (not parsed)
	}

	elsif( $property eq 'http://purl.org/eprint/terms/copyrightHolder' )
	{
		# COPYRIGHT HOLDER (not parsed)
	}

	return;
}


sub clean_text
{
	my ( $text ) = @_;

	my @lines = split( "\n", $text );

	foreach(@lines)
	{
		$_ =~ s/\s+$//;

		$_ =~ s/^\s+//;
	}

	return join(" ", @lines);
}




        



1;

