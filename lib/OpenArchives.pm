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
use EPrints::Log;
use EPrints::Session;
use EPrintSite::SiteRoutines;

use Unicode::String qw(utf8 latin1);
use strict;


# Supported version of OAI
$EPrints::OpenArchives::OAI_VERSION = "1.0";


######################################################################
#
# $stamp = $full_timestamp()
#
#  Return a full timestamp of the form YYYY-MM-DDTHH:MM:SS[GMT-delta]
#
#  e.g. 2000-05-01T15:32:23+01:00
#
######################################################################

sub full_timestamp
{
	my $time = time;
	my @date = localtime( $time );

	my $day = $date[3];
	my $month = $date[4]+1;
	my $year = $date[5]+1900;
	my $hour = $date[2];
	my $min = $date[1];
	my $sec = $date[0];
	
	# Ensure number of digits
	while( length $day < 2 )   { $day   = "0".$day; }
	while( length $month < 2 )	{ $month = "0".$month; }
	while( length $hour < 2 )  { $hour  = "0".$hour; }
	while( length $min < 2 )	{ $min   = "0".$min; }
	while( length $sec < 2 )   { $sec   = "0".$sec; }

	# Find difference between gmt and local time zone
	my @gmtime = gmtime( $time );

	# Offset in minutes
	my $offset = $date[1] - $gmtime[1] + ( $date[2] - $gmtime[2] ) * 60;
	
	# Ensure no boundary crossed by checking day of the year...
	if( $date[7] == $gmtime[7]+1 )
	{
		# Next day
		$offset += 1440;
	}
	elsif( $date[7] == $gmtime[7]+1 )
	{
		# Previous day
		$offset -= 1440;
	}
	elsif( $date[7] < $gmtime[7] )
	{
		# Crossed year boundary
		$offset +=1440
	}
	elsif( $date[7] > $gmtime[7] )
	{
		# Crossed year boundary
		$offset -=1440;
	}
	
	# Work out in hours and minutes
	my $unsigned_offset = ( $offset < 0 ? -$offset : $offset );
	my $minutes_offset = $unsigned_offset % 60;
	my $hours_offset = ( $unsigned_offset-$minutes_offset ) / 60;
	
	while( length $hours_offset < 2 )  { $hours_offset = "0".$hours_offset; }
	while( length $minutes_offset < 2 )
	{
		$minutes_offset = "0".$minutes_offset;
	}

	# Return full timestamp
	return( "$year-$month-$day"."T$hour:$min:$sec".
		( $offset < 0 ? "-" : "+" ) . "$hours_offset:$minutes_offset" );
}


######################################################################
#
# write_record( $session, $writer, $eprint, $metadataFormat )
#
#  Write XML corresponding to the given eprint and metadata format.
#  This method doesn't check that the metadata format is available 
#  for the given eprint; if it isn't, a record with no <metadata>
#  element will be written.
#
######################################################################

sub write_record
{
	my( $session, $writer, $eprint, $metadataFormat ) = @_;
	
	$writer->startTag( "record" );

	# Write the OAI header
	EPrints::OpenArchives::write_record_header( $writer,
	                                            $eprint->{eprintid},
	                                            $eprint->{datestamp} );


	# Get the metadata
	my $metadata = EPrints::OpenArchives::get_eprint_metadata(
		$eprint,
		$metadataFormat );

	if( defined $metadata )
	{
		# Write the metadata
		$writer->startTag( "metadata" );

		EPrintSite::SiteRoutines::oai_write_eprint_metadata(
			$eprint,
			$metadataFormat,
			$writer);
		
		$writer->endTag( "metadata" );
	}
	
	$writer->endTag(); # Ends the "record" tag
}


					

######################################################################
#
# write_record_header( $writer, $eprint_id, $datestamp )
#
#  Writes the OAI record header for the given eprint ID, with the
#  given datestamp.
#
######################################################################

sub write_record_header
{
	my( $session, $writer, $eprint_id, $datestamp ) = @_;
	
	$writer->startTag( "header" );

	$writer->dataElement(
		"identifier",
		EPrints::OpenArchives::to_oai_identifier( 
			$session->{site}->{oai_archive_id},
			$eprint_id ) );
	
	$writer->dataElement( "datestamp",
	                      $datestamp );
	
	$writer->endTag();
}


######################################################################
#
# $oai_identifier = to_oai_identifier( $site_id , $eprint_id )
#
#  Give the full OAI identifier of an eprint, given the local eprint id.
#
######################################################################

sub to_oai_identifier
{
	my( $site_id , $eprint_id ) = @_;
	
	return( "oai:$site_id:$eprint_id" );
}


######################################################################
#
# $eprint_od = from_oai_identifier( $session , $oai_identifier )
#
#  Return the local eprint id of an oai eprint identifier. undef is
#  returned if the full id is garbled.
#
######################################################################

sub from_oai_identifier
{
	my( $session , $oai_identifier ) = @_;
	
	if( $oai_identifier =~
		/^oai:$session->{site}->{oai_archive_id}:($session->{site}->{eprint_id_stem}\d+)$/ )
	{
		return( $1 );
	}
	else
	{
		return( undef );
	}
}


######################################################################
#
# $metadata = get_eprint_metadata( $eprint, $metadataFormat )
#
#  Return the metadata for the given eprint in the given format.
#  Returns undef if we cannot produce metadata in the requested
#  format.
#
######################################################################

sub get_eprint_metadata
{
	my( $eprint, $metadataFormat ) = @_;
	
	if( defined $eprint->{session}->{site}->{oai_metadata_formats}->{$metadataFormat} )
	{
		my %md = EPrintSite::SiteRoutines::oai_get_eprint_metadata(
			$eprint,
			$metadataFormat );

		return( \%md ) if( scalar keys %md > 0 );
	}

	return( undef );
}


######################################################################
#
# $encoded = to_utf8( $unencoded )
#
#  Convert latin1 to UTF-8
#
######################################################################

sub to_utf8
{
	my( $in ) = @_;
	my $u = latin1( $in );
	return( $u->utf8() );
}


######################################################################
#
# @eprints = harvest( $session, $start_date, $end_date, $setspec )
#
#  Retrieve eprint records matching the given spec.
#
######################################################################

sub harvest
{
	my( $session, $start_date, $end_date, $setspec ) = @_;
	
	my $searchexp = make_harvest_search(
		$session,
		$start_date,
		$end_date,
		$setspec,
		EPrints::Database::table_name( "archive" ),
		$session->{metainfo}->find_table_field( "eprint", "datestamp" ),
		$session->{metainfo}->find_table_field( "eprint", "subjects" ) );

	return( $searchexp->do_eprint_search() );
}


######################################################################
#
# @eprint_ids = harvest_deleted( $session, $start_date, $end_date, $setspec )
#
#  Retrieve id's of deleted records matching the given spec.
#
######################################################################

sub harvest_deleted
{
	my( $session, $start_date, $end_date, $setspec ) = @_;
	
	my @deletion_fields = $session->{metainfo}->get_fields( "deletions" );

	my $searchexp = make_harvest_search(
		$session,
		$start_date,
		$end_date,
		$setspec,
		EPrints::Database::table_name( "deletion" ),
		EPrints::MetaInfo::find_field(
			\@deletion_fields,
			"deletiondate" ),
		EPrints::MetaInfo::find_field(
			\@deletion_fields,
			"subjects" ) );

	my $rows = $searchexp->do_raw_search( [ "eprintid" ] );
	my @eprint_ids;
	
	foreach (@$rows)
	{
		push @eprint_ids, $_->[0];
	}

	return( @eprint_ids );
}



######################################################################
#
# $searchexpression = make_harvest_search( $session,
#                                          $start_date,
#                                          $end_date,
#                                          $setspec,
#                                          $table,
#                                          $date_field,
#                                          $subject_field
#
#  Make a SearchExpression suitable for harvesting between $start_date
#  and $end_date, with the set specification $setspec.  Any or all of
#  these three fields may be undef.  $table is the database table to
#  search, $date_field and $subject_field are the MetaFields to use
#  for the harvesting.
#
######################################################################

sub make_harvest_search
{
	my( $session, $start_date, $end_date, $setspec, $table, $date_field,
		$subject_field ) = @_;

	# Create a search expression
	my $searchexp = new EPrints::SearchExpression(
		$session,
		$table,
		0,
		1,
		[],
		{},
		undef );

	# Add date component for 
	if( defined $start_date || defined $end_date )
	{
		my $date_search_spec = ( defined $start_date ? $start_date : "" ) . "-" .
		( defined $end_date ? $end_date : "" );

#cjg?
		$searchexp->add_field(
			$date_field,
			$date_search_spec );
	}
	
	# set component
	if( defined $setspec )
	{
		# Get the subjects the setspec pertains to
		my @subjects = setspec_to_subjects( $session, $setspec );
		
		# Make our search field
		my $subject_search_spec;
		foreach (@subjects)
		{
			$subject_search_spec .= ":$_->{subjectid}";
		}
		$subject_search_spec .= ":ANY";

#cjg?
		$searchexp->add_field(
			$subject_field,
			$subject_search_spec );
	}

	return( $searchexp );
}	


######################################################################
#
# @subjects = setspec_to_subjects( $session, $setspec )
#
#  Return Subject objects representing subjects that are in the scope
#  of the given setspec.
#
######################################################################

sub setspec_to_subjects
{
	my( $session, $setspec ) = @_;
	
	# Ignore everything except the last part of the spec.  We don't
	# need the path.
	$setspec =~ s/.*://;
	
	# Get the corresponding subject.
	my $subject = new EPrints::Subject( $session, $setspec );
	
	# Make sure we actually have one
	return( undef ) unless( defined $subject );
	
	# Now get all descendents of this subject, since they will all fall
	# in the scope of the setspec
	my @subjects_in_scope;
	_collect_subjects( \@subjects_in_scope, $subject );
	
	return( @subjects_in_scope );
}


######################################################################
#
# _collect_subjects( $subjects_array, $parent )
#
#  Put the parent and all of it's children in the array.
#
######################################################################

sub _collect_subjects
{
	my ( $subjects_array, $parent ) = @_;
	
	push @$subjects_array, $parent;
	
	my @children = $parent->children();
	foreach (@children)
	{
		_collect_subjects( $subjects_array, $_ );
	}
}


######################################################################
#
# $valid = $validate_set_spec( $session, $setspec )
#
#  Returns nonzero if the setspec is valid.
#
######################################################################

sub validate_set_spec
{
	my( $session, $setspec ) = @_;

	# Split the parts of the setspec up
	my @parts = split /:/, $setspec;

	# Root subject
	my $subject = new EPrints::Subject( $session, undef );

	# Make sure the path is valid
	my $part;
	foreach $part (@parts)
	{
		my @children = $subject->children();
		my $child;
		
		# Make sure the child exists
		foreach (@children)
		{
			$child = $_ if( $part eq $_->{subjectid} );
		}
		
		return( 0 ) unless ( defined $child );

		$subject = $child;
	}

	return( 1 );
}



1;
