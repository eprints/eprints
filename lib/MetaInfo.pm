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

	my $self = {};
	bless $self, $class;

	$self->{site} = $site;
	#
	# Read in system and site USER metadata fields
	#

	$self->{user_meta_fields} = [];
	$self->{document_meta_fields} = [];
	$self->{subscription_meta_fields} = [];
	$self->{subject_fields} = [];
	$self->{deletion_meta_fields} = [];
	$self->{eprint_meta_types} = [];         # Metadata EPrint types (id's.) This is only
                           		#  really here so that the order can be retained
                               		#  from the cfg file.
	$self->{eprint_meta_fields} = [];        # ALL EPrint metadata fields.
	$self->{eprint_meta_fieldnames} = [];    # The field IDs, cached in an array for speed
	$self->{eprint_system_fields} = [];      # The system EPrint metadata fields
	$self->{eprint_meta_type_fields} = {};   # Maps EPrint types -> list of fields they need.
                               		# Always includes the system ones.
	$self->{eprint_type_names}  = {};         # Maps EPrint types -> displayable names
	
	$self->{eprint_field_help}  = {};         # Maps EPrint metadata fields->brief help
	$self->{eprint_field_index} = {};        # Maps EPrint metadata field names -> MetaField
                               		#  objects

	
	foreach (@EPrints::User::system_meta_fields)
	{
		my $field = EPrints::MetaField->new( $_ );
		$field->{help} = $EPrints::User::help{$_};
		push @{$self->{user_meta_fields}}, $field;
	}

	push @{$self->{user_meta_fields}}, EPrints::MetaField::read_fields(
		 $site->{user_meta_file} );


	#
	# Read in system document metadata fields
	# (none from config file yet)
	#
	foreach (@EPrints::Document::meta_fields)
	{
		my $field = EPrints::MetaField->new( $_ );
		$field->{help} = $EPrints::Document::help{$field->{name}};
		push @{$self->{document_meta_fields}}, $field;
	}


	#
	# SUBJECT metadata fields
	# (none from config file yet)
	#
	foreach (@EPrints::Subject::system_meta_fields)
	{
		push @{$self->{subject_fields}}, EPrints::MetaField->new( $_ );
	}


	#
	# SUBSCRIPTION metadata fields
	# (none from config file yet)
	#
	foreach (@EPrints::Subscription::system_meta_fields)
	{
		push @{$self->{subscription_meta_fields}}, EPrints::MetaField->new( $_ );
	}
		

	#
	# EPRINT Fields
	#

	# Read in the system fields, common to all EPrint types
	foreach (@EPrints::EPrint::system_meta_fields)
	{
		my $field = new EPrints::MetaField( $_ );
		$field->{help} = $EPrints::EPrint::help{$field->{name}};
		push @{$self->{eprint_meta_fields}}, $field;
		push @{$self->{eprint_meta_fieldnames}}, $field->{name};
		push @{$self->{eprint_system_fields}}, $field;
	}

	# Read in all the possible site fields
	my @fields = EPrints::MetaField::read_fields(
		 $site->{eprint_fields_file} );
	
	foreach (@fields)
	{
		$self->{eprint_field_index}->{$_->{name}} = $_;
		push @{$self->{eprint_meta_fields}}, $_;
		push @{$self->{eprint_meta_fieldnames}}, $_->{name};
	}


	#
	# DELETION TABLE fields
	# (none from config file yet)
	#
	foreach (@EPrints::Deletion::system_meta_fields)
	{
		push @{$self->{deletion_meta_fields}}, EPrints::MetaField->new( $_ );
	}
	

	#
	# EPrint types
	#
	$self->read_types( $site->{eprint_types_file} );
	
	return $self;
}


######################################################################
#
# read_types( $file )
#
#  read in the EPrint types
#
######################################################################

sub read_types
{
	my( $self , $file ) = @_;
	
	my @inbuffer;

	unless( open CFG_FILE, $file )
	{
		EPrints::Log::log_entry( 
				"L:type_file_err",
				{ file=>$file,
				errmsg=>$! } );

		return;
	}

	while( <CFG_FILE> )
	{
		chomp();
		next if /^\s*#/;
		push @inbuffer, $_;

		if( /<\/class>/i )
		{
			$self->make_type( @inbuffer );

			@inbuffer = ();
		}
	}

	close( CFG_FILE );
}


######################################################################
#
# make_type( @lines )
#
#  Make an EPrint type from the given config file lines.
#
######################################################################

sub make_type
{
	my( $self , @lines ) = @_;
	
	my $type;

	foreach (@lines)
	{
		# Get the class tag and display name out of <class "tag" "name">
		if( /<class\s+"*([^"]+)"*\s+"*([^"]+)"*>/ )
		{
			$type = $1;
			$self->{eprint_type_names}->{$type} = $2;
			push @{$self->{eprint_meta_types}}, $type;

			# Put in system defaults
			$self->{eprint_meta_type_fields}->{$type} = [];
			
			foreach (@{$self->{eprint_system_fields}})
			{
				push @{$self->{eprint_meta_type_fields}->{$type}}, $_;
			}
		}
		elsif( /<\/class>/i )
		{
			# End of the class
			return;
		}
		# Get the field out of a line "[REQUIRE] field_name"
		elsif( /(require)?\s*"*([^"]+)"*/i )
		{
			# Make a copy of the relevant field, with required flag set
			# if necessary
			my $required = 0;
			$required = 1 if( (lc $1) eq "require" );
			my $field = $self->{eprint_field_index}->{$2};
			
			if( !defined $field )
			{
				EPrints::Log::log_entry( 
					"L:unknown_field",
						{ field => $2,
						class => $type } );
				return;
			}
			
			my $new_field = $field->clone();
			$new_field->{required} = $required;

			# Put copy in type hash			
			push @{$self->{eprint_meta_type_fields}->{$type}}, $new_field;
		}
		# Can ignore everything else
	}
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
  
sub get_eprint_types
{
	my( $self ) = @_;

	return( @{$self->{eprint_meta_types}} );
}


######################################################################
#
# @eprint_types = get_eprint_type_names()
#
#  Return the display names of EPrint types supported by the system
#
######################################################################
  
sub get_eprint_type_names
{
	my( $self ) = @_;

	return( $self->{eprint_type_names} );
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
# $field = get_fields( $table )
#
#  Get table metadata fields by tablename
#
######################################################################

sub get_fields
{
	my ( $self , $table ) = @_;

	if ( $table eq "users") 
	{
		return( @{$self->{user_meta_fields}} );
	}
	if ( $table eq "documents") 
	{
		return( @{$self->{document_meta_fields}} );
	}
	if ( $table eq "subjects") 
	{
		return( @{$self->{subject_fields}} );
	}
	if ( $table eq "subscriptions") 
	{
		return( @{$self->{subscription_meta_fields}} );
	}
	if ( $table eq "deletions") 
	{
		return( @{$self->{deletion_meta_fields}} );
	}
	if ( $table eq "inbox" ||
	     $table eq "buffer" ||
	     $table eq "archive" ) 
	{
		return( @{$self->{eprint_meta_fields}} );
	}
	# eprints isn't a table per se but it makes life easier
	# to be able to identify this as a type too.
	if ( $table eq "eprints" )
	{
		return( @{$self->{eprint_meta_fields}} );
	}

	EPrints::Log::log_entry( "L:unknown_table", { table=>$table } );
	return undef;
}


1;
