######################################################################
#
# EPrints::Plugin::Sword::Import::METS
#
######################################################################
#
#  __COPYRIGHT__
#
# Copyright 2000-2008 University of Southampton. All Rights Reserved.
# 
#  __LICENSE__
#
######################################################################

######################################################################
#
# PURPOSE:
#
#	This will import XML files of MD type 'epdcx' (only). Some metadata
#	is not currently parsed.
#
# METHODS:
#
# input_files( $plugin, %opts ):
#       The method called by DepositHandler. The %opts hash contains
#       information on which files to import.
#
######################################################################


package EPrints::Plugin::Sword::Import::METS;

use strict;

use EPrints::Plugin::Import::TextFile;

our @ISA = qw/ EPrints::Plugin::Import::TextFile /;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new( %params );

	$self->{name} = "SWORD Importer - METS/EPDCX METS/MODS (alpha)";
	$self->{visible} = "all";
	$self->{accept} = "text/xml";

	return $self;
}


sub input_file
{
        my ( $plugin, %opts ) = @_;

        my $session = $plugin->{session};

        my $input_files = $opts{files};
        my $dir = $opts{dir};

	# Let's find the XML file to import:
        my $infile = EPrints::Sword::Utils::get_file_to_import( $session, $input_files, "text/xml" );
        
        my $dataset_id = $opts{dataset_id};
        my $owner_id = $opts{owner_id};
        my $depositor_id = $opts{depositor_id};

	my $fh;
	if( !open( $fh, $infile ) )
	{
		print STDERR "\n[SWORD-METS] [ERROR] I couldnt open the file: $infile because $!";
		return;
	}

	# Hack to find out in which directory the XML file is located (useful later when the documents are created)
	my $unpack_dir;
	my $fntmp;

	$fntmp = $infile;

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
		return;
	}


        my $dom_doc;
        eval
        {
                $dom_doc = EPrints::XML::parse_xml_string( $xml );
        };

        if($@ || !defined $dom_doc)
        {
                print STDERR "\n[SWORD-METS] [ERROR] Couldnt parse the xml.";
                return;
        }

	return if( !defined $dom_doc );

        my $dom_top = $dom_doc->getDocumentElement;

	return if( lc $dom_top->tagName ne 'mets' );

	# METS Headers (ignored)
	my $mets_hdr = ($dom_top->getElementsByTagName( "metsHdr" ))[0];

	# METS Descriptive Metadata (main section for us)
	my $dmd_sec = ($dom_top->getElementsByTagName( "dmdSec" ))[0];

	return if( !defined $dmd_sec );

	# need to extract xmlData from here
	my $md_wrap = ($dmd_sec->getElementsByTagName( "mdWrap" ))[0];

	return if( !defined $md_wrap );

	if(!( lc $md_wrap->getAttribute( "MDTYPE" ) eq 'other' && defined $md_wrap->getAttribute( "OTHERMDTYPE" ) && lc $md_wrap->getAttribute( "OTHERMDTYPE" ) eq 'epdcx' ))
	{
		# Wrong type of METS document 
		return;
	}

	my $xml_data = ($md_wrap->getElementsByTagName( "xmlData" ))[0];

	return if(!defined $xml_data);

	my $epdata = parse_epdcx_xml_data( $xml_data );

	return unless defined $epdata;

	# File Section which will contain optional info about files to import:
	my $file_sec = ($dom_top->getElementsByTagName( "fileSec" ))[0];

	my @files;
	if( defined $file_sec )
	{
	        my $file_grp = ($dom_top->getElementsByTagName( "fileGrp" ))[0];

        	$file_sec = $file_grp if( defined $file_grp );	# this is because the <fileGrp> tag is optional

		foreach my $file_div ($file_sec->getElementsByTagName( "file" ))
		{
			my $file_loc = ($file_div->getElementsByTagName( "FLocat" ))[0];
			if(defined $file_loc)
			{		# yeepee we have a file (maybe)

				my $fn = $file_loc->getAttribute( "href" );
				next unless defined($fn);

				next if $fn =~ /^http/;	# wget those files?

				push @files, $fn;				
			}
		}

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

	return unless(defined $eprint);

	foreach my $file (@files)
	{
	        my %doc_data;
	        $doc_data{eprintid} = $eprint->get_id;

		$doc_data{format} = EPrints::Sword::FileType::checktype_filename( $unpack_dir."/".$file );
		$doc_data{main} = $file;

	        my %file_data;
	       	$file_data{filename} = $file;
		$file_data{data} = $unpack_dir."/".$file;

        	$doc_data{files} = [ \%file_data ];

	        my $doc_dataset = $session->get_repository->get_dataset( "document" );

		my $document = EPrints::DataObj::Document->create_from_data( $session, \%doc_data, $doc_dataset );

        	if(!defined $document)
                {
                	print STDERR "\n[SWORD-METS] [ERROR] Failed to add the attached file to the eprint.";
                }
	}

	return $eprint->get_id;

}


sub parse_epdcx_xml_data
{
	my ( $xml ) = @_;

	my $set = ($xml->getElementsByTagName( "descriptionSet" ))[0];

	return unless defined $set;

	my $epdata = {};

	foreach my $desc ($set->getElementsByTagName( "description" ))
	{

		foreach my $stat ($desc->getElementsByTagName( "statement" ))
		{
#			print STDERR "\nGot statement: ".$stat->getAttribute( "propertyURI" );
	
			my ($field, $value) = parse_statement( $stat );

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



sub parse_statement
{
	my ( $stat ) = @_;

	my $property = $stat->getAttribute( "propertyURI" );

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

