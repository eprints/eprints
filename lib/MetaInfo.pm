######################################################################
#
# EPrints Metadata Information Module
#
#  Holds and maintains information about metadata fields.
#
#
#  The user metadata format is:
#
#  field_name:type:arguments:display name:required?:user editable?:
#  publically visible?
#   1 = true, 0 = false for the last three.
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

package EPrints::MetaInfo;
use strict;

use EPrints::EPrint;
use EPrints::User;
use EPrints::MetaField;
use EPrints::Document;
use EPrints::Log;
use EPrints::Subject;
use EPrints::Subscription;


######################################################################
#
# new()
#cjg comment 
#  Reads in the metadata fields from the config files.
#
######################################################################

## WP1: BAD
sub new
{
	my( $class , $site ) = @_;

die "NEW METAINFO\n";


}

######################################################################
#
#
######################################################################


######################################################################
#
#
######################################################################
  


######################################################################
#
# $field = find_field( $fields, $field_name )
#                     array_ref
#
#  Utility function to find a particular field from an array of
#  fields. [STATIC]
#
######################################################################

## WP1: BAD
sub find_field
{
	my( $fields, $field_name ) = @_;
	my $f;
	
	foreach $f (@$fields)
	{
		return( $f ) if( $f->{name} eq $field_name );
	}
	
	return( undef );
}


######################################################################
#
# $field = find_table_field( $tableid, $field_name )
#
#  Find a specific table field
#
######################################################################

## WP1: BAD
sub find_table_field
{
	my( $self , $tableid,  $field_name ) = @_;
	die "Bad Tableid: $tableid" if ( !defined $self->{$tableid} );
	
	return( find_field( $self->{$tableid}->{fields}, $field_name ) );
}

######################################################################
#
