######################################################################
#
# EPrints::Plugin::Sword::Import::IMS
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
#	This is a basic importer for IMS. It can parse a minimal
#	amount of metadata and attached files.
#
# METHODS:
#
# input_files( $plugin, %opts ):
#       The method called by DepositHandler. The %opts hash contains
#       information on which files to import.
#
######################################################################

package EPrints::Plugin::Sword::Import::IMS;

use strict;

use EPrints::Plugin::Import::TextFile;

our @ISA = qw/ EPrints::Plugin::Import::TextFile /;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new( %params );

	$self->{name} = "SWORD Importer - IMS";
	$self->{visible} = "all";
	
	$self->{accept} = "text/xml";

	return $self;
}


sub input_file
{
	my ( $plugin, %opts ) = @_;

	my $session = $plugin->{session};

	my $input_files = $opts{files};
	
	# Let's find the XML file first:
	my $infile = EPrints::Sword::Utils::get_file_to_import( $session, $input_files, "text/xml" );

	return unless(defined $infile);

	my $dataset_id = $opts{dataset_id};
	my $owner_id = $opts{owner_id};
	my $depositor_id = $opts{depositor_id};

	my $fh;
	if( !open( $fh, $infile ) )
	{
		print STDERR "\nI couldnt open the file: $infile";
		return;
	}


	# hack to find out in which directory the XML file is located (useful later..)
        my $unpack_dir;
        my $fntmp = $infile;

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
		print STDERR "\n[SWORD-IMS] [INTERNAL-ERROR] Failed to open the dataset '$dataset_id'.";
		return;
	}

	my $dom_doc;
	eval
	{
	        $dom_doc = EPrints::XML::parse_xml_string( $xml );
	};

	if($@ || !defined $dom_doc)
	{
		print STDERR "\n[SWORD-IMS] [ERROR] Couldnt parse the xml.";
		return;
	}

	# Need to find the right sections in XML. We return 'undef' anytime a sub-section is not found.
	my $dom_top = $dom_doc->getDocumentElement;
	return unless defined( $dom_top );

	my $metadata = ($dom_top->getElementsByTagName( "metadata" ))[0];
	return unless defined( $metadata );

	my $lom = ($metadata->getElementsByTagName( "lom" ))[0];
	return unless defined( $lom );

	my $general = ($lom->getElementsByTagName( "general" ))[0];
	return unless defined( $general );

	my $title_wrap = ($general->getElementsByTagName( "title" ))[0];
	return unless defined( $title_wrap );

	my $title = ($title_wrap->getElementsByTagName( "langstring" ))[0];

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
	
	return unless( defined $eprint );
	
	foreach my $file (@files)
	{
	        my %doc_data;
	        $doc_data{eprintid} = $eprint->get_id;
		# try to guess the MIME of the attached file:
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
			print STDERR "\n[SWORD-IMS] [ERROR] Failed to add the attached file to the eprint.";
		}
	}

	return $eprint->get_id;
}
















1;






