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

print STDERR "NEW METAINFO\n";

	my $self = {};
	bless $self, $class;

	$self->{site} = $site;
	#
	# Read in system and site USER metadata fields
	#

	foreach( TID_USER, TID_DOCUMENT, TID_SUBSCRIPTION,
		TID_SUBJECT, TID_EPRINT, TID_DELETION )
	{
		$self->{$_} = {};
		$self->{$_}->{fields} = [];
		$self->{$_}->{system_fields} = [];
		$self->{$_}->{field_index} = {};
		my $class = EPrints::Database::table_class( $_ );
		
		my $field_data;
		my @data = $class->get_system_field_info( $site );
		if( defined $site->{sitefields}->{$_} )
		{
			push @data, @{ $site->{sitefields}->{$_} };
		}
		foreach $field_data ( @data )
		{
			$field_data->{tableid} = $_;
			my $field = EPrints::MetaField->new( $field_data );
			push @{$self->{$_}->{fields}}, $field;
			push @{$self->{$_}->{system_fields}}, $field;
			$self->{$_}->{field_index}->{$field_data->{name}} = $field;
		}

	}

	$self->{types} = {};
	my $tableid;
	foreach $tableid ( keys %{$site->{sitetypes}} )
	{
		$self->{$tableid}->{types} = {};
		my $type;
		foreach $type ( keys %{$site->{sitetypes}->{$tableid}} )
		{
print STDERR "$tableid:$type\n";
			$self->{$tableid}->{types}->{$type} = [];
			foreach (@{$self->{$tableid}->{system_fields}})
			{
				push @{$self->{$tableid}->{types}->{$type}}, $_;
			}
			foreach ( @{$site->{sitetypes}->{$tableid}->{$type}} )
			{
				my $required = ( s/^REQUIRED:// );
				my $field = $self->{$tableid}->{field_index}->{$_};
				if( !defined $field )
				{

					EPrints::Log::log_entry( 
						"L:unknown_field",
						{ field => $_, class => $type } );
					return;
				}
				if( $required )
				{
					$field = $field->clone();
					$field->{required} = 1;
				}
				push @{$self->{$tableid}->{types}->{$type}}, $field;
			}
		}
	}

	$self->{inbox} = $self->{buffer} = $self->{archive} = $self->{eprint};

	return $self;
}

######################################################################
#
#
######################################################################
  
sub get_types
{
	my( $self, $tableid ) = @_;

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
	
        return $session->{lang}->phrase( "A:typename_".$tableid."_".$type );
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

sub get_order_names
{
	my( $self, $session, $tableid ) = @_;
		
	my %names = ();
	foreach( keys %{$session->{site}->{order_methods}->{$tableid}} )
	{
		$names{$_}=$self->get_order_name( $session, $tableid, $_ );
	}
	return( \%names );
}

sub get_order_name
{
	my( $self, $session, $tableid, $orderid ) = @_;
	
        return $session->{lang}->phrase( "A:ordername_".$tableid."_".$orderid );
}




1;
