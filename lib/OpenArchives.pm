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
use EPrints::Session;

use strict;


# Supported version of OAI
$EPrints::OpenArchives::OAI_VERSION = "1.1";


######################################################################
#
# $stamp = $full_timestamp()
#
#  Return a full timestamp of the form YYYY-MM-DDTHH:MM:SS[GMT-delta]
#
#  e.g. 2000-05-01T15:32:23+01:00
#
######################################################################

## WP1: BAD
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


sub make_record
{
	my( $session, $eprint, $fn ) = @_;

	my $record = $session->make_element( "record" );
	my $header = $session->make_element( "header" );
	$header->appendChild( $session->render_data_element(
		6,
		"identifier",
		EPrints::OpenArchives::to_oai_identifier(
			$session->get_archive()->get_conf( "oai", "archive_id" ),
			$eprint->get_value( "eprintid" ) ) ) );
	$header->appendChild( $session->render_data_element(
		6,
		"datestamp",
		$eprint->get_value( "datestamp" ) ) );
	$record->appendChild( $session->make_indent( 4 ) );
	$record->appendChild( $header );

	if( $eprint->get_dataset()->id() eq "deletion" )
	{
		$record->setAttribute( "status" , "deleted" );
		return $record;
	}

	my $md = &{$fn}( $eprint, $session );
	if( defined $md )
	{
		my $metadata = $session->make_element( "metadata" );
		$metadata->appendChild( $session->make_indent( 6 ) );
		$metadata->appendChild( $md );
		$record->appendChild( $session->make_indent( 4 ) );
		$record->appendChild( $metadata );
	}

	return $record;
}

######################################################################
#
# $oai_identifier = to_oai_identifier( $archive_id , $eprintid )
#
#  Give the full OAI identifier of an eprint, given the local eprint id.
#
######################################################################

## WP1: BAD
sub to_oai_identifier
{
	my( $archive_id , $eprintid ) = @_;
	
	return( "oai:$archive_id:$eprintid" );
}


######################################################################
#
# $eprint_od = from_oai_identifier( $session , $oai_identifier )
#
#  Return the local eprint id of an oai eprint identifier. undef is
#  returned if the full id is garbled.
#
######################################################################

## WP1: BAD
sub from_oai_identifier
{
	my( $session , $oai_identifier ) = @_;
	my $arcid = $session->get_archive()->get_conf( "oai", "archive_id" );
	if( $oai_identifier =~ /^oai:$arcid:(\d+)$/ )
	{
		return( $1 );
	}
	else
	{
		return( undef );
	}
}





##

sub encode_setspec
{
	my( @bits ) = @_;
	foreach( @bits ) { $_ = text2bytestring( $_ ); }
	return join(":",@bits);
}

sub decode_setspec
{
	my( $encoded ) = @_;
	my @bits = split( ":", $encoded );
	foreach( @bits ) { $_ = bytestring2text( $_ ); }
	return @bits;
}

sub text2bytestring
{
	my( $string ) = @_;
	my $encstring = "";
	for(my $i=0; $i<length($string); $i++)
	{
		$encstring.=sprintf("%02X", ord(substr($string, $i, 1)));
	}
	return $encstring;
}

sub bytestring2text
{
	my( $encstring ) = @_;

	my $string = "";
	for(my $i=0; $i<length($encstring); $i+=2)
	{
		$string.=pack("H*",substr($encstring,$i,2));
	}
	return $string;
}


1;

