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

use EPrints::EPrint;
use EPrints::User;
use EPrints::MetaField;
use EPrints::Document;
use EPrints::Log;
use EPrints::Subject;
use EPrints::Subscription;

use strict;


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

	foreach( "user", "document", "subscription", "subject", "eprint" , "deletion" )
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
# @eprint_types = get_eprint_types()
#
#  Return the EPrint types supported by the system, in the order that
#  they appear in the cfg file (which, one hopes, is the order that
#  the site administrators wish it to appear!
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
# @eprint_types = get_eprint_type_names()
#
#  Return the display names of EPrint types supported by the system
#
######################################################################
  
sub get_type_names
{
	my( $self, $tableid ) = @_;
		
	my %names = ();
	foreach( keys %{$self->{$tableid}->{types}} ) 
	{
		$names{$_}="$_ (lang support pending)";
	}
	return( \%names );
}


######################################################################
#
# @meta_field_names = get_all_eprint_fieldnames()
#
#  Get ALL EPrint field names, cached for speed
#
######################################################################

sub get_all_eprint_fieldnames
{
	my( $self ) = @_;

	return( @{$self->{eprint_meta_fieldnames}} );
}



######################################################################
#
# @meta_fields = get_eprint_fields( $type )
#
#  Gives appropriate metadata fields for the given EPrint type,
#  including the system ones.
#
######################################################################

sub get_eprint_fields
{
	my( $self, $type ) = @_;
	
	my $fields = $self->{eprint_meta_type_fields}->{$type};

	if( !defined $fields )
	{
		EPrints::Log::log_entry( "L:no_fields", { type=>$type } );
		return( undef );
	}

	return( @$fields );
}


######################################################################
#
# $name = get_eprint_type_name( $type )
#
#  Returns the displayable name of the given EPrint type,
#
######################################################################

sub get_eprint_type_name
{
	my( $self, $type ) = @_;
	
	return( $self->{eprint_type_names}->{$type} );
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
# $field = find_eprint_field( $field_name )
#
#  Find a specific eprint field
#
######################################################################

sub find_eprint_field
{
	my( $self , $field_name ) = @_;
	
	return( find_field( $self->{eprint_meta_fields}, $field_name ) );
}

######################################################################
#
# $field = find_table_field( $table , $field_name )
#
#  Find a specific eprint field
#
######################################################################

sub find_table_field
{
	my( $self, $table , $field_name ) = @_;

	my @fields = $self->get_fields( $table );

	return( find_field( \@fields, $field_name ) );
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


1;
