######################################################################
#
# EPrints::Plugin::Sword::Import::Jpeg
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
#	This handles JPEG files and attaches them to an empty EPrint object.
#	This is a copy of the Pdf module.
#
# METHODS:
#
# input_files( $plugin, %opts ):
#       The method called by DepositHandler. The %opts hash contains
#       information on which files to import.
#
######################################################################

package EPrints::Plugin::Sword::Import::Jpeg;

use strict;

use EPrints::Plugin::Import::TextFile;

our @ISA = qw/ EPrints::Plugin::Import::TextFile /;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new( %params );

	$self->{name} = "SWORD Importer - JPEG";
	$self->{visible} = "all";
	
	$self->{accept} = "image/jpeg";

	return $self;
}


sub input_file
{
	my ( $plugin, %opts ) = @_;

	my $session = $plugin->{session};

	# We need to get ALL the files of type 'image/jpeg'
	my $f = EPrints::Sword::Utils::get_file_to_import( $session, $opts{files}, "image/jpeg", 1 );

	return unless( defined $f );

	my @files = @{$f};

	my $dir = $opts{dir};

	my $dataset_id = $opts{dataset_id};
	my $owner_id = $opts{owner_id};
	my $depositor_id = $opts{depositor_id};

	my $dataset = $session->get_archive()->get_dataset( $dataset_id );

	if(!defined $dataset)
        {
                print STDERR "\n[SWORD-JPEG] [INTERNAL-ERROR] Failed to open the dataset '$dataset_id'.";
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
		
	return unless( defined $eprint );
	
	# Attaching every JPEG found:
	foreach my $infile (@files)
	{
	       my $unpack_dir;
	       my $fn;

	       $fn = $infile;

	       if( $fn =~ /^(.*)\/(.*)$/ )
	       {
             		$unpack_dir = $1;
	                $fn = $2;
	       }

	       my %doc_data;
	       $doc_data{eprintid} = $eprint->get_id;
	       $doc_data{format} = "image/jpeg";

		$doc_data{main} = $fn;

		my %file_data;

	        $file_data{filename} = $fn;
	        $file_data{data} = $infile;

        	$doc_data{files} = [ \%file_data ];

		my $doc_dataset = $session->get_repository->get_dataset( "document" );

		my $document = EPrints::DataObj::Document->create_from_data( $session, \%doc_data, $doc_dataset );

                if(!defined $document)
                {
                        print STDERR "\n[SWORD-JPEG] [ERROR] Failed to add the attached file to the eprint.";
	        }
		else
		{
			$document->make_thumbnails();			
		}

	}

	$eprint->generate_static();

	return $eprint->get_id;
}



1;
