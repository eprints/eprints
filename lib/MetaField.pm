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
@EPrints::MetaField::FieldInfo =
(
	"name",            # The field name, as it appears in the database
	"type",            # The (EPrints) field type
	"arguments",       # Arguments, depends on the field type
	"displayname",     # Displayable (English) name
	"required",        # 0 if the field is optional, 1 if required
	"editable",        # 1 if the field is user-editable
	"visible",         # 1 if the field is publically visible
	"indexed"          # Make an index in the database
);



# The following are worked out from appropriate metadata field types:
#
# \@tags
# \%labels
# $displaylines
# $multiple
# $displaydigits

######################################################################
#
# new_terse( $config_line )
#
#  Construct a new metadata field info object from the terse
#  colon-separated format. $config_line should be
#  a colon-separated list of the fields listed above, in that order
#  (minus any \n that might have been read in from a file). If
#  $config_line is undefined, makes a blank MetaField object.
#
#  Generally this is only used internally by EPrints modules.
#
######################################################################

sub new
{
	my( $class, $config_line ) = @_;
	
	my $self = {};
	bless $self, $class;
	
	return( $self ) if( !defined( $config_line ) );

	my @fields = split /:/, $config_line;
	my $field;
	my $i = 0;
	
	foreach $field (@fields)
	{
		$self->{$EPrints::MetaField::FieldInfo[$i]} = $field;
		$i++;
	}

	if( $self->{type} eq "set" )
	{
		$self->{tags} = [];
		$self->{labels} = {};

		my @possibles = split /;/, $self->{arguments};
	
		# Work out the no. of lines to display, the first value in the arguments
		# list.
		$self->{displaylines} = shift @possibles;

		# Multiple?
		$self->{multiple} = shift @possibles;

		# Work out the tags, and the tag labels. From the arguments field,
		# in the form tag,label;tag,label;...
		my $p;
		foreach $p (@possibles)
		{
			my( $tag, $label ) = split /,/, $p;
			push @{$self->{tags}}, $tag;
			$self->{labels}->{$tag} = $label;
		}
	}
	elsif( $self->{type} eq "int" )
	{
		# display digits is simply the whole argument
		$self->{displaydigits} = $self->{arguments};
	}
	elsif( $self->{type} eq "multitext" )
	{
		# display digits is simply the whole argument
		$self->{displaylines} = $self->{arguments};
	}
	elsif( $self->{type} eq "subject" )
	{
		# A set, but one that need to read in the subject fields.
		$self->{multiple} = $self->{arguments};
	}
	elsif( $self->{type} eq "eprinttype" )
	{
		# Tricky one this... would ideally call MetaInfo::get_eprint_types(),
		# but this could cause a nasty infinite loop. So, we'll leave this one
		# for MetaInfo->read_meta_fields() to sort out.
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
	
	my $clone = new EPrints::MetaField;
	foreach (keys %{$self})
	{
		$clone->{$_} = $self->{$_};
	}
	
	return( $clone );
}


######################################################################
#
# $field = make_field( @fieldspec )
#
#  Create a field from the given field spec, in the config file format
#
######################################################################

sub make_field
{
	my( $class, @fieldspec ) = @_;
	
	my $self = {};
	bless $self, $class;
	
	# Do each line of the field spec
	foreach (@fieldspec)
	{
		# Match <field "fieldname">
		if( /<field "*(\w+)"*>/i )
		{
			$self->{name} = lc $1;
#EPrints::Log::debug( "MetaField", "Got field named $self->{name}" );
		}
		# Match KEY = VALUE
		elsif( /^(\w+)\s*=\s*"*([^"]+)"*$/i )
		{
			my $key = lc $1;
			my $val = $2;

			
			# Boolean ones
			if( $key eq "multiple" || $key eq "required" || $key eq "editable" ||
				$key eq "visible" || $key eq "index" )
			{
				if( $val =~ /yes/i || $val =~ /true/i )
				{
					$self->{$key} = 1;
				}
				elsif( $val =~ /no/i || $val =~ /false/i )
				{
					$self->{$key} = 0;
				}
				else
				{
					EPrints::Log::log_entry(
						"MetaField",
						EPrints::Language::logphrase(
							"L:bad_value",
							$key,
							$self->{name} ) );
				}
			}
			# type
			elsif( $key eq "type" )
			{
				# Check it's a valid type
				if( !defined $EPrints::Database::datatypes{lc $val} )
				{
					EPrints::Log::log_entry(
						"MetaField",
						EPrints::Language::logphrase(
							"L:bad_type",
							$key,
							$self->{name} ) );
					return( undef );
				}
				else
				{
					$self->{type} = lc $val;
				}
			}
			elsif( $key eq "help" )
			{
				if( defined $self->{help} )
				{
					$self->{help} .= $val;
				}
				else
				{
					$self->{help} = $val;
				}					
			}
			else
			{
				# Just lob the value in
				$self->{$key} = $val;
			}
		}
		# Match VALUE tag = label
		elsif( /value\s+"*(\w+)"*\s*=\s*"*([^"]+)"*$/i )
		{
			if( !defined $self->{tags} )
			{
				$self->{tags} = [ $1 ];
				$self->{labels} = { $1 => $2 };
			}
			else
			{
				push @{$self->{tags}}, $1;
				$self->{labels}->{$1} = $2;
			}
		}
	}
	
	# Over-ride index settings [cjg]

	if( $self->{type} ne "pagerange" && 
	    $self->{type} ne "multitext" )
	{
		$self->{indexed} = 1;
	}
	

	# Sanity checks
	if( !defined $self->{type} ||
		!defined $self->{name} ||
		!defined $self->{displayname} )
	{
		EPrints::Log::log_entry(
			"MetaField",
			EPrints::Language::logphrase(
				"L:not_all_info",
				$self->{name} ) );

#EPrints::Log::debug( "MetaField", "TYPE $self->{type} NAME $self->{name} DISPLAYNAME $self->{displayname}" );
	}
	
	return( $self );
}


######################################################################
#
# @fields = read_fields( $file )
#
#  Read in a load of metadata fields from a config file.
#
######################################################################

sub read_fields
{
	my( $file ) = @_;
	
	my @fields;
	my @inbuffer;
	
	unless( open CFG_FILE, $file )
	{
		EPrints::Log::log_entry( 
			"MetaInfo",
			EPrints::Language::logphrase(
				"L:cant_open_file",
				$file,
				$! ) );
		return;
	}
	
	while( <CFG_FILE> )
	{
		chomp();
		next if /^\s*#/;
		push @inbuffer, $_;

		if( /<\/field>/i )
		{
			my $new_field = EPrints::MetaField->make_field( @inbuffer );
			push @fields, $new_field;

			@inbuffer = ();
		}
	}

	close( CFG_FILE );
	
	return( @fields );
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

1;
