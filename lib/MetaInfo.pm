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

use EPrintSite::SiteInfo;

use strict;

my @user_meta_fields;
my @document_meta_fields;
my @subscription_meta_fields;
my @subject_fields;
my @eprint_meta_types;         # Metadata EPrint types (id's.) This is only
                               #  really here so that the order can be retained
                               #  from the cfg file.
my @eprint_meta_fields;        # ALL EPrint metadata fields.
my @eprint_meta_fieldnames;    # The field IDs, cached in an array for speed
my @eprint_system_fields;      # The system EPrint metadata fields
my %eprint_meta_type_fields;   # Maps EPrint types -> list of fields they need.
                               # Always includes the system ones.
my %eprint_type_names;         # Maps EPrint types -> displayable names

my %eprint_field_help;         # Maps EPrint metadata fields->brief help
my %eprint_field_index;        # Maps EPrint metadata field names -> MetaField
                               #  objects


######################################################################
#
# read_meta_fields()
# 
#  Reads in the metadata fields from the config files.
#
######################################################################

sub read_meta_fields
{
	#
	# Read in system and site USER metadata fields
	#
	@user_meta_fields = ();
	
	foreach (@EPrints::User::system_meta_fields)
	{
		my $field = EPrints::MetaField->new( $_ );
		$field->{help} = $EPrints::User::help{$_};
		push @user_meta_fields, $field;
	}

	push @user_meta_fields, EPrints::MetaField::read_fields(
		 $EPrintSite::SiteInfo::user_meta_config );


	#
	# Read in system document metadata fields
	# (none from config file yet)
	#
	foreach (@EPrints::Document::meta_fields)
	{
		my $field = EPrints::MetaField->new( $_ );
		$field->{help} = $EPrints::Document::help{$field->{name}};
		push @document_meta_fields, $field;
	}


	#
	# SUBJECT metadata fields
	# (none from config file yet)
	#
	foreach (@EPrints::Subject::system_meta_fields)
	{
		push @subject_fields, EPrints::MetaField->new( $_ );
	}


	#
	# SUBSCRIPTION metadata fields
	# (none from config file yet)
	#
	foreach (@EPrints::Subscription::system_meta_fields)
	{
		push @subscription_meta_fields, EPrints::MetaField->new( $_ );
	}
		

	#
	# EPRINT Fields
	#

	# Read in the system fields, common to all EPrint types
	foreach (@EPrints::EPrint::system_meta_fields)
	{
		my $field = new EPrints::MetaField( $_ );
		$field->{help} = $EPrints::EPrint::help{$field->{name}};
		push @eprint_meta_fields, $field;
		push @eprint_meta_fieldnames, $field->{name};
		push @eprint_system_fields, $field;
	}

	# Read in all the possible site fields
	my @fields = EPrints::MetaField::read_fields(
		 $EPrintSite::SiteInfo::site_eprint_fields );
	my %field_index;
	
	foreach (@fields)
	{
		$eprint_field_index{$_->{name}} = $_;
		push @eprint_meta_fields, $_;
		push @eprint_meta_fieldnames, $_->{name};
	}

	
	#
	# EPrint types
	#
	EPrints::MetaInfo::read_types( $EPrintSite::SiteInfo::site_eprint_types );
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
	my( $file ) = @_;
	
	my @inbuffer;

	unless( open CFG_FILE, $file )
	{
		EPrints::Log::log_entry( "MetaInfo",
		                         "Can't open eprint types file: $file: $!" );
		return;
	}

	while( <CFG_FILE> )
	{
		chomp();
		push @inbuffer, $_;

		if( /<\/class>/i )
		{
			EPrints::MetaInfo::make_type( @inbuffer );

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
	my( @lines ) = @_;
	
	my $type;

	foreach (@lines)
	{
		# Get the class tag and display name out of <class "tag" "name">
		if( /<class\s+"*([^"]+)"*\s+"*([^"]+)"*>/ )
		{
			$type = $1;
			$eprint_type_names{$type} = $2;
			push @eprint_meta_types, $type;

			# Put in system defaults
			$eprint_meta_type_fields{$type} = [];
			
			foreach (@eprint_system_fields)
			{
				push @{$eprint_meta_type_fields{$type}}, $_;
			}
		}
		elsif( /<\/class>/i )
		{
			# End of the class
#EPrints::Log::debug( "MetaInfo", "Read class $type with $#{$eprint_meta_type_fields{$type}} fields" );
			return;
		}
		# Get the field out of a line "[REQUIRE] field_name"
		elsif( /(require)?\s*"*([^"]+)"*/i )
		{
			# Make a copy of the relevant field, with required flag set
			# if necessary
			my $required = 0;
			$required = 1 if( (lc $1) eq "require" );
			my $field = $eprint_field_index{$2};
			
			if( !defined $field )
			{
				EPrints::Log::log_entry( "Unknown EPrint field $2 in class $type" );
				return;
			}
			
			my $new_field = $field->clone();
			$new_field->{required} = $required;

			# Put copy in type hash			
			push @{$eprint_meta_type_fields{$type}}, $new_field;
		}
		# Can ignore everything else
	}
}


######################################################################
#
# @meta_fields = get_user_fields()
#
#  Get the user metadata fields
#
######################################################################

sub get_user_fields
{
	# Ensure we've read in the metadata fields
	read_meta_fields if( $#user_meta_fields == -1 );
	
	return( @user_meta_fields );
}


######################################################################
#
# @meta_fields = get_document_fields()
#
#  Get document file metadata fields
#
######################################################################

sub get_document_fields
{
	# Ensure we've read in the metadata fields
	read_meta_fields if( $#document_meta_fields == -1 );

	return( @document_meta_fields );
}


######################################################################
#
# @meta_fields = get_subject_fields()
#
#  Get subject category metadata fields
#
######################################################################

sub get_subject_fields
{
	# Ensure we've read in the metadata fields
	read_meta_fields if( $#subject_fields == -1 );

	return( @subject_fields );
}


######################################################################
#
# @meta_fields = get_subscription_fields()
#
#  Get subscription metadata fields
#
######################################################################

sub get_subscription_fields
{
	# Ensure we've read in the metadata fields
	read_meta_fields if( $#subscription_meta_fields == -1 );

	return( @subscription_meta_fields );
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
	# Ensure we've read in the metadata fields
	read_meta_fields if( $#eprint_meta_types == -1 );

	return( @eprint_meta_types );
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
	# Ensure we've read in the metadata fields
	read_meta_fields if( $#eprint_meta_types == -1 );

	return( \%eprint_type_names );
}



######################################################################
#
# @meta_fields = get_all_eprint_fields()
#
#  Get ALL EPrint fields
#
######################################################################

sub get_all_eprint_fields
{
	# Ensure we've read in the metadata fields
	read_meta_fields if( $#eprint_meta_fields == -1 );

	return( @eprint_meta_fields );
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
	# Ensure we've read in the metadata fields
	read_meta_fields if( $#eprint_meta_fields == -1 );

	return( @eprint_meta_fieldnames );
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
	my( $type ) = @_;
	
	# Ensure we've read in the metadata fields
	read_meta_fields if( $#eprint_meta_fields == -1 );
	
	my $fields = $eprint_meta_type_fields{$type};

	if( !defined $fields )
	{
		EPrints::Log::log_entry( "MetaInfo", "No fields for EPrint type $type" );
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
	my( $type ) = @_;
	
	# Ensure we've read in the metadata fields
	read_meta_fields if( $#eprint_meta_fields == -1 );
	
	return( $eprint_type_names{$type} );
}


######################################################################
#
# $field = find_field( $fields, $field_name )
#                     array_ref
#
#  Utility function to find a particular field from an array of
#  fields.
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
	my( $field_name ) = @_;
	
	# Ensure we've read in the metadata fields
	read_meta_fields if( $#eprint_meta_fields == -1 );

	return( EPrints::MetaInfo::find_field( \@eprint_meta_fields,
	                                       $field_name ) );
}

1;
