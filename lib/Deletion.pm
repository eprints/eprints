######################################################################
#
# EPrints Deletion Module
#
#  Handles information concerning the removal of Eprints, and later
#  versions thereof
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

package EPrints::Deletion;

use EPrints::Database;
use EPrints::EPrint;
use EPrints::MetaInfo;
use EPrints::SearchField;
use EPrints::Session;

use strict;


@EPrints::Deletion::system_meta_fields =
(
	"eprintid:text::EPrint ID:1:0:0",
	"replacement:text::ID of Replacement:1:0:0",
	"subjects:subject:1:Subject Categories:0:0:0",
	"deletiondate:date::Date Removed:1:0:0"
);


######################################################################
#
# $deletion_record = new( $session, $eprintid, $known )
#
#  Get the deletion record for the given eprint.  undef returned if
#  the eprint doesn't have a deletion record. $known, as usual, is the
#  array of rows from the database if they've already been retrieved.
#
######################################################################

sub new
{
	my( $class, $session, $eprintid, $known ) = @_;
	
	my $self={};
	bless $self, $class;

	$self->{session} = $session;
	$self->{eprintid} = $eprintid;
	
	my @row;

	if( !defined $known )
	{
		# Need to read data from the database
		@row = $self->{session}->{database}->retrieve_single(
			$EPrints::Database::table_deletion,
			"eprintid",
			$self->{eprintid} );
	}
	else
	{
		@row = @$known;
	}

	# If nothing matches, we have no deletion record for the given ID
	return( undef ) if( scalar @row == 0 );

	# Lob row data into relevant field
	my @fields = EPrints::MetaInfo::get_fields( "deletions" );
	my $i=0;
	foreach (@fields)
	{
		my $field_name = $_->get("name");

		$self->{$field_name} = $row[$i];
		$i++;
	}

	return( $self );
}


######################################################################
#
# $record = $add_deletion_record( $eprint )
#
#  Adds a deletion record to the database for the given eprint,
#  datestamped today.  The replacement is automatically set to the
#  most recent eprint in the version thread, if the eprint is in a
#  thread.
#
######################################################################

sub add_deletion_record
{
	my( $eprint ) = @_;
	
	# Inherit the eprint's session
	my $session = $eprint->{session};

	# Deletion date is today
	my $deletion_date = EPrints::MetaField::get_datestamp( time );

	# Replacement is last in thread
	my $last_in_thread = $eprint->last_in_thread(
		EPrints::MetaInfo::find_eprint_field( "succeeds" ) );
	
	my $replacement = $last_in_thread->{eprintid};
	
	if( $eprint->{eprintid} eq $replacement )
	{
		# This is the last in the thread, so we set the replacement to the
		# eprint that this eprint succeeds (which may of course be null, if the
		# eprint isn't in a thread)
		$replacement = $eprint->{succeeds};
	}

	# Set $replacement to "NULL" if appropriate
	#$replacement = "NULL" unless( defined $replacement && $replacement ne "" );
	
	# Now add the deletion record to the database
#cjg add_record call
	return( undef ) unless ( $session->{database}->add_record(
		$EPrints::Database::table_deletion,
		{ "eprintid"=>$eprint->{eprintid},
		  "replacement"=>$replacement,
		  "subjects"=>$eprint->{subjects},
		  "deletiondate"=>$deletion_date } ) );

	return( new EPrints::Deletion(
		$session,
		$eprint->{eprintid},
		[ $eprint->{eprintid}, $replacement, $deletion_date ] ) );
}

1;
