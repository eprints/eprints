######################################################################
#
# EPrints Metadata Field class
#
#  Holds information about a metadata field
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

package EPrints::MetaField;

use EPrints::Log;
use EPrints::Database;

use strict;

#
# The following is the information about the metadata field. This is the
# format of the terse in-line code version, which should be colon-separated.
# i.e. name:type:arguments:displayname:...
#
#@EPrints::MetaField::FieldInfo =
#(
	#"name",            # The field name, as it appears in the database
	#"type",            # The (EPrints) field type
	#"arguments",       # Arguments, depends on the field type
	#"displayname",     # Displayable (English) name
	#"required",        # 0 if the field is optional, 1 if required
	#"editable",        # 1 if the field is user-editable
	#"visible",         # 1 if the field is publically visible
	#"multiple"         # Is a multiple field
#);



# The following are worked out from appropriate metadata field types:
#
# \@tags
# \%labels
# $displaylines
# $multiple
# $displaydigits

######################################################################
#
##
# cjg comment?
######################################################################
# name   **required**
# type   **required**
# required # default = no
# editable # default = no
# visible  # default = no
# multiple # default = no
# tableid # for help & name 
# 
# displaylines   # for longtext and set (int)   # default = 5
# digits  # for int  (int)   # default = 20
# options # for set (array)   **required if type**
# maxlength # for something

# note: display name, help and labels for options are not
# defined here as they are lang specific.

sub new
{
	my( $class, $data ) = @_;
	
	my $self = {};
	bless $self, $class;

	#if( $_[1] =~ m/[01]:[01]:[01]/ ) { print STDERR "---\n".join("\n",caller())."\n"; die "WRONG KIND OF CALL TO NEW METAFIELD: $_[1]"; } #cjg to debug

	foreach( "name","type" )
	{
		if( !defined $data->{$_} )
		{
			die "No $_ defined for field.";	
		}
		$self->{$_} = $data->{$_};
	}
	foreach( "required","editable","visible","multiple","tableid" )
	{
		$self->{$_} = ( defined $data->{$_} ? $data->{$_} : 0 );
	}
	if( $self->{type} eq "longtext" || $self->{type} eq "set" )	
	{
		$self->{displaylines} = ( defined $data->{displaylines} ? $data->{displaylines} : 5 );
	}
	if( $self->{type} eq "int" )
	{
		$self->{digits} = ( defined $data->{digits} ? $data->{digits} : 20 );
	}
	if( $self->{type} eq "text" )
	{
		$self->{maxlength} = $data->{maxlength};
	}
	if( $self->{type} eq "set" )
	{
		if( !defined $data->{options} )
		{
			die "NO OPTIONS for FIELD: $data->{name}\n";
		}
		$self->{options} = $data->{options};	
	}

	return( $self );
}


######################################################################
#
# $metafield = make_set( $name, $display_name,  $lines,
#                        $tags,    $labels, $multiple )
#                       array_ref  hash_ref
#
#  Function for making a MetaField with the given tags and values.
#  Tags are given in $tags so that order can be maintained. $labels
#  should map the tags to more useful text. If $multiple is non-zero,
#  more than one item in the set may be selected.
#
######################################################################

sub make_set
{
	my( $class, $name, $display_name, $lines, $tags, $labels, $multiple ) = @_;
	
	my $self = {};
	bless $self, $class;
	
	$self->{name} = $name;
	$self->{displayname} = $display_name;
	$self->{tags} = $tags;
	$self->{labels} = $labels;
	$self->{multiple} = $multiple;
	$self->{displaylines} = $lines;
	$self->{type} = "set";

	return( $self );
}


######################################################################
#
# $value = get( $field )
#
#  Get information about the metadata field.
#
######################################################################

sub get
{
	my( $self, $field ) = @_;
	
	return( $self->{$field} );
}


######################################################################
#
# $clone = clone()
#
#  Clone the field, so the clone can be edited without affecting the
#  original. (Exception: the tag and label fields - only the references
#  are copied, not the full array/hash.)
#
######################################################################

sub clone
{
	my( $self ) = @_;

	return EPrints::MetaField->new( $self );
}



######################################################################
#
# ( $year, $month, $day ) = get_date( $time )
#
#  Static method that returns the given time (in UNIX time, seconds 
#  since 1.1.79) in the format used by EPrints and MySQL (YYYY-MM-DD).
#
######################################################################

sub get_date
{
	my( $time ) = @_;

	my @date = localtime( $time );
	my $day = $date[3];
	my $month = $date[4]+1;
	my $year = $date[5]+1900;
	
	# Ensure number of digits
	while( length $day < 2 )
	{
		$day = "0".$day;
	}

	while( length $month < 2 )
	{
		$month = "0".$month;
	}

	return( $year, $month, $day );
}


######################################################################
#
# $datestamp = get_datestamp( $time )
#
#  Static method that returns the given time (in UNIX time, seconds 
#  since 1.1.79) in the format used by EPrints and MySQL (YYYY-MM-DD).
#
######################################################################

sub get_datestamp
{
	my( $time ) = @_;

	my( $year, $month, $day ) = EPrints::MetaField::get_date( $time );

	return( $year."-".$month."-".$day );
}


sub tags_and_labels
{
	my( $self , $session ) = @_;
	my %labels = ();
	foreach( @{$self->{options}} )
	{
		$labels{$_} = "$_ multilang opts not done";
	}
	return ($self->{options}, \%labels);
}

sub displayname
{
	my( $self, $session ) = @_;
	return "LANG(".$self->{name}.")";
}
1;
