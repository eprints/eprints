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
use EPrints::Constants;


######################################################################
#
# new()
#cjg comment 
#  Reads in the metadata fields from the config files.
#
######################################################################

sub new
{
	my( $class , $site ) = @_;

die "NEW METAINFO\n";


}

######################################################################
#
#
######################################################################
  
sub get_types
{
	my( $self, $tableid ) = @_;
	die "Bad Tableid: $tableid" if ( !defined $self->{$tableid} );

	my @types =  sort keys %{$self->{$tableid}->{types}};
	
	return \@types;
}


######################################################################
#
#
######################################################################
  
sub get_type_names
{
	my( $self, $session, $tableid ) = @_;
	die "Bad Tableid: $tableid" if ( !defined $self->{$tableid} );
		
	my %names = ();
	foreach( keys %{$self->{$tableid}->{types}} ) 
	{
		$names{$_}=$self->get_type_name( $session, $tableid, $_ );
	}
	return( \%names );
}


######################################################################
#
#
#  Returns the displayable name of the given type,
#
######################################################################

sub get_type_name
{
	my( $self, $session, $tableid, $type ) = @_;
	die "Bad Tableid: $tableid" if ( !defined $self->{$tableid} );
        return $session->{lang}->phrase( 
		"A:typename_".
		EPrints::Database::table_string( $tableid ).
		"_".$type );
}


######################################################################
#
# $field = find_field( $fields, $field_name )
#                     array_ref
#
#  Utility function to find a particular field from an array of
#  fields. [STATIC]
#
######################################################################

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

sub find_table_field
{
	my( $self , $tableid,  $field_name ) = @_;
	die "Bad Tableid: $tableid" if ( !defined $self->{$tableid} );
	
	return( find_field( $self->{$tableid}->{fields}, $field_name ) );
}

######################################################################
#
# $field = get_fields( $tableid )
#
#  Get table metadata fields by tableid
#
######################################################################

sub get_fields
{
	my ( $self , $tableid ) = @_;
	die "Bad Tableid: $tableid" if ( !defined $self->{$tableid} );
print STDERR "GF: $tableid\n";

	if( !defined $self->{$tableid}->{fields} )
	{
		EPrints::Log::log_entry( "L:unknown_table", { table=>$tableid } );
print STDERR join(",",caller())."\n";
		return undef;
	}
	return @{$self->{$tableid}->{fields}};
}

###




1;
