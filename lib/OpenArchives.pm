######################################################################
#
#  EPrints OpenArchives Support Module
#
#   Methods for open archives support in EPrints.
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

package EPrints::OpenArchives;

use EPrints::Database;
use EPrints::EPrint;
use EPrints::MetaField;
use EPrints::MetaInfo;
use EPrints::Session;
use EPrintSite::SiteInfo;
use EPrintSite::SiteRoutines;

use strict;

# This is the character used to separate the unique archive ID from the
# record ID in full Dienst record identifiers

$EPrints::OpenArchives::id_separator = ":";


######################################################################
#
# %tags = disseminate( $fullID )
#
#  Return OAMS tags corresponding to the given fullID. If the fullID
#  can't be resolved to an existing EPrint, and empty hash is returned.
#
######################################################################

sub disseminate
{
	my( $fullID ) = @_;
	
	my( $arc_id, $record_id ) = split /$EPrints::OpenArchives::id_separator/,
	                            $fullID;

	# Return an error unless we have values for both archive ID and record ID,
	# and the archive identifier received matches our archive identifier.
	return( () ) unless( defined $arc_id && defined $record_id &&
		$arc_id eq $EPrintSite::SiteInfo::archive_identifier );
	
	# Create a new non-script session
	my $session = new EPrints::Session( 1 );
	
	# Try and get the EPrint
	my $eprint = new EPrints::EPrint( $session,
	                                  $EPrints::Database::table_archive,
	                                  $record_id );

	# Get the tags (get_oams_tags returns empty hash if $eprint is undefined)
	my %tags = EPrints::OpenArchives::get_oams_tags( $eprint );
	
	$session->terminate();
	
	return( %tags );
}


######################################################################
#
# @partitions = partitions()
#
#  Return the subject hierarchy as partitions for the OA List Partitions
#  verb. Format is:
#
#  partition = { name => partition_id, display => "partition display name" }
#
#  partitionnode = [ partition, partitionnode, ... ]
#
#  @partitions = ( partitionnode, partitionnode, ... ) for top-level partitions
#
######################################################################

sub partitions
{
	# Create non-script session
	my $session = new EPrints::Session( 1 );

	my $toplevel_subject = new EPrints::Subject( $session, undef );
	
	return( _partitionise_subjects( $toplevel_subject ) );
}


######################################################################
#
# @partitions = partitionise_subjects( $subject )
#
#  Gets the child subjects of $subject, and puts them together with their
#  children in a list. i.e. returns them as partitionnodes (from partitions()
#  definition.)
#
######################################################################

sub _partitionise_subjects
{
	my( $subject ) = @_;

	my @partitions = ();

	my @children = $subject->children();
	
	# Cycle through each of the child subjects, adding the partitionnode to
	# the list of partitions to return
	foreach (@children)
	{
		my %partitionnode = ( name    => $_->{subjectid},
		                      display => $_->{name} );
		my @child_partitions = _partitionise_subjects( $_ );
		
		push @partitions, [ \%partitionnode, \@child_partitions ];
	}

	return( @partitions );
}


######################################################################
#
# $fullID = fullID( $eprint )
#
#  Return a full Dienst ID for the given eprint.
#
######################################################################

sub fullID
{
	my( $eprint ) = @_;
	
	return( $EPrintSite::SiteInfo::archive_identifier .
	        $EPrints::OpenArchives::id_separator .
	        $eprint->{eprintid} );
}


######################################################################
#
# $valid = valid_fullID( $fullID )
#
#  Returns non-zero if $fullID is valid.
#
######################################################################

sub valid_fullID
{
	my( $fullID ) = @_;
	
	my( $arc_id, $record_id ) = split /$EPrints::OpenArchives::id_separator/,
	                            $fullID;

	# Return true if we have values for both archive ID and record ID,
	# and the archive identifier received matches our archive identifier.
	return( defined $arc_id && defined $record_id &&
		$arc_id eq $EPrintSite::SiteInfo::archive_identifier );
}


######################################################################
#
# %tags = get_oams_tags( $eprint )
#
#  Get OAMS tags for the given eprint.
#
######################################################################

sub get_oams_tags
{
	my( $eprint) = @_;

	# If the EPrint doesn't exist, we will return the empty hash
	return( () ) unless( defined $eprint );
	
	my %tags = ();

	# Fill out the system tags

	# Date of accession (submission) - fortunately uses the same format
	$tags{accession} = $eprint->{datestamp};

	# Display ID (URL)
	$tags{displayId} = [ $eprint->static_page_url() ];

	# FullID
	$tags{fullId} = &fullID( $eprint );

	# Other tags are site-specific. Delegate to site routine.
	EPrintSite::SiteRoutines::eprint_get_oams( $eprint, \%tags );

	return( %tags );
}


######################################################################
#
# @eprints = list_contents( $partitionspec, $fileafter )
#
#  Return the eprints corresponding to the given partitionspec and
#  submitted after the given date
#
######################################################################

sub list_contents
{
	my( $partitionspec, $fileafter ) = @_;
	
	# First, need a non-script session
	my $session = new EPrints::Session( 1 );
	
	# Create a search expression
	my $searchexp = new EPrints::SearchExpression(
		$session,
		$EPrints::Database::table_archive,
		0,
		1,
		[],
		\%EPrintSite::SiteInfo::eprint_order_methods,
		undef );
	
	# Add the relevant fields

	if( defined $partitionspec && $partitionspec ne "" )
	{
		# Get the subject field
		my $subject_field = EPrints::MetaInfo::find_eprint_field( "subjects" );

		# Get the relevant subject ID. Since all subjects have unique ID's, we
		# can just remove everything specifying the ancestry.
		$partitionspec =~ s/.*;//;

		$searchexp->add_field( $subject_field, "$partitionspec:ANY" );
	}
	
	if( defined $fileafter && $fileafter ne "" )
	{
		# Get the datestamp field
		my $datestamp_field = EPrints::MetaInfo::find_eprint_field( "datestamp" );
		
		$searchexp->add_field( $datestamp_field, "$fileafter-" );
	}
	
	return( $searchexp->do_eprint_search() );
}


1;
