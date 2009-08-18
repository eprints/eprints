######################################################################
#
# EPrints::MetaField
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

=pod

=head1 NAME

B<EPrints::MetaField> - A single metadata field.

=head1 SYNOPSIS

	my $field = $dataset->get_field( $fieldname );

	# you must clone a field to modify any properties
	$newfield = $field->clone;
	$newfield->set_property( $property, $value );

	$name = $field->get_name;
	$type = $field->get_type;
	$value = $field->get_property( $property );
	$boolean = $field->is_type( @typenames );
	$results = $field->call_property( $property, @args ); 
	# (results depend on what the property sub returns)

	$xhtml = $field->render_name( $handle );
	$xhtml = $field->render_help( $handle );
	$xhtml = $field->render_value( $handle, $value, $show_all_langs, $dont_include_links, $object );
	$xhtml = $field->render_single_value( $handle, $value );
	$xhtml = $field->get_value_label( $handle, $value );

	$values = $field->get_values( $handle, $dataset, %opts );

	$sorted_list = $field->sort_values( $handle, $unsorted_list );

=head1 DESCRIPTION

Theis object represents a single metadata field, not the value of
that field. A field belongs (usually) to a dataset and has a large
number of properties. Optional and required properties vary between 
types.

"type" is the most important property, it is the type of the metadata
field. For example: "text", "name" or "date".

A full description of metadata types and properties is in the eprints
documentation and will not be duplicated here.

=cut

######################################################################
#
# INSTANCE VARIABLES:
#
#  $self->{confid}
#     The conf-id of the dataset to which this field belongs. If this
#     field is not part of a dataset then this is just a string used 
#     to find config info about this field. Most importantly the name
#     and other information from the phrase file.
#
#  $self->{repository}
#     The repository to which this field belongs.
#
# The rest of the instance variables are the properties of the field.
# The most important properties (which are always required) are:
#
#  $self->{name}
#     The name of this field.
#
#  $self->{type}
#     The type of this field.
#
######################################################################

package EPrints::MetaField;

use strict;

use Text::Unidecode qw();

$EPrints::MetaField::VARCHAR_SIZE 	= 255;
# get the default value from field defaults in the config
$EPrints::MetaField::FROM_CONFIG 	= "272b7aa107d30cfa9c67c4bdfca7005d_FROM_CONFIG";
# don't use a default, the code may have already set this value. setting it to undef
# has no effect rather than setting it to default value.
$EPrints::MetaField::NO_CHANGE	 	= "272b7aa107d30cfa9c67c4bdfca7005d_NO_CHANGE";
# this field must be explicitly set
$EPrints::MetaField::REQUIRED 		= "272b7aa107d30cfa9c67c4bdfca7005d_REQUIRED";
# this field defaults to undef
$EPrints::MetaField::UNDEF 		= "272b7aa107d30cfa9c67c4bdfca7005d_UNDEF";

######################################################################
# $field = EPrints::MetaField->new( %properties )
# 
# Create a new metafield. %properties is a hash of the properties of the 
# field, with the addition of "dataset", or if "dataset" is not set then
# "confid" and "repository" must be provided instead.
# 
# Some field types require certain properties to be explicitly set. See
# the main documentation.
######################################################################

sub new
{
	my( $class, %properties ) = @_;

	# We'll inherit these from clone()
	delete $properties{".final"};
	delete $properties{"field_defaults"};

	my $realclass = "EPrints::MetaField::\u$properties{type}";
	eval 'use '.$realclass.';';
	EPrints::abort "couldn't parse $realclass: $@" if $@;

	###########################################
	#
	# Pre 2.4 compatibility 
	#

	# for when repository was called archive.
	if( defined $properties{archive} )
	{
		$properties{repository} = delete $properties{archive};
	}

	# end of 2.4
	###########################################

	# allow metafields to override new()
	if( $class ne $realclass )
	{
		return $realclass->new( %properties );
	}

	my $self = {};
	bless $self, $realclass;

	$self->{confid} = delete $properties{confid};
	$self->{repository} = delete $properties{repository};

	if( defined $properties{dataset} ) 
	{ 
		$self->{confid} = $properties{dataset}->confid(); 
		$self->{repository} = $properties{dataset}->get_repository;
		$self->{dataset} = delete $properties{dataset};
		if( defined( &Scalar::Util::weaken ) )
		{
			Scalar::Util::weaken( $self->{dataset} );
		}
	}

	if( !defined $self->{repository} )
	{
		EPrints::abort( 
			"Tried to create a metafield without a ".
			"dataset or an repository." );
	}

	if( defined &Scalar::Util::weaken )
	{
		Scalar::Util::weaken( $self->{repository} );
	}

	if( !defined $properties{name} )
	{
		if( defined $properties{sub_name} && defined $properties{parent_name} )
		{
			$properties{name} = $properties{parent_name}."_".$properties{sub_name};
		}
		else 
		{
			EPrints::abort( "A sub field needs sub_name and parent_name to be set." );
		}
	}

	# This gets reset later, but we need it for potential
	# debug messages.
	$self->{type} = $properties{type};
	
	$self->{field_defaults} = $self->{repository}->get_field_defaults( $properties{type} );
	if( !defined $self->{field_defaults} )
	{
		my %props = $self->get_property_defaults;
		$self->{field_defaults} = {};
		foreach my $p_id ( keys %props )
		{
			if( defined $props{$p_id} && $props{$p_id} eq $EPrints::MetaField::FROM_CONFIG )
			{
				my $v = $self->{repository}->get_conf( "field_defaults" )->{$p_id};
				if( !defined $v )
				{
					$v = $EPrints::MetaField::UNDEF;
				}
				$props{$p_id} = $v;
			}
			$self->{field_defaults}->{$p_id} = $props{$p_id};
		}
		$self->{repository}->set_field_defaults( $properties{type}, $self->{field_defaults} );
	}

	keys %{$self->{field_defaults}}; # Reset each position
	while(my( $p_id, $p_default ) = each %{$self->{field_defaults}})
	{
		my $p_value = delete $properties{$p_id};
		if( defined $p_value )
		{
			$self->{$p_id} = $p_value;
		}
		elsif( $p_default eq $EPrints::MetaField::REQUIRED )
		{
			EPrints::abort( "Error in field property for ".$self->{dataset}->id.".".$self->{name}.": $p_id on a ".$self->{type}." metafield can't be undefined" );
		}
		elsif
		  (
			$p_default ne $EPrints::MetaField::UNDEF &&
			$p_default ne $EPrints::MetaField::NO_CHANGE
		  )
		{
			$self->{$p_id} = $p_default;
		}
	}

	foreach my $p_id (keys %properties)
	{
		# warn of non-applicable parameters; handy for spotting
		# typos in the config file.
		$self->{repository}->log( "Field '".$self->{dataset}->id.".".$self->{name}."' has invalid parameter:\n$p_id => $properties{$p_id}" );
	}

	return $self;
}

######################################################################
# $field->final
# 
# This method tells the metafield that it is now read only. Any call to
# set_property will produce a abort error.
######################################################################

sub final
{
	my( $self ) = @_;

	$self->{".final"} = 1;
}


######################################################################
=pod

=head1 METHODS

=over 4

=item $field->set_property( $property, $value )

Set the named property to the given value.

This should not be called on metafields unless they've been cloned
first.

This method will cause an abort error if the metafield is read only.

In these cases a cloned version of the field should be used.

=cut
######################################################################

sub set_property
{
	my( $self , $property , $value ) = @_;

	if( $self->{".final"} )
	{
		EPrints::abort( <<END );
Attempt to set property "$property" on a finalised metafield.
Field: $self->{name}, type: $self->{type}
END
	}

	if( !defined $self->{field_defaults}->{$property} )
	{
		EPrints::abort( <<END );
BAD METAFIELD get_property property name: "$property"
Field: $self->{name}, type: $self->{type}
END
	}

	if( defined $value )
	{
		$self->{$property} = $value;
		return;
	}

	if( $self->{field_defaults}->{$property} eq $EPrints::MetaField::NO_CHANGE )
	{
		# don't set a default, just leave it alone
		return;
	}
	
	if( $self->{field_defaults}->{$property} eq $EPrints::MetaField::REQUIRED )
	{
		EPrints::abort( "Error in field property for ".$self->{dataset}->id.".".$self->{name}.": $property on a ".$self->{type}." metafield can't be undefined" );
	}

	if( $self->{field_defaults}->{$property} eq $EPrints::MetaField::UNDEF )
	{	
		$self->{$property} = undef;
		return;
	}

	$self->{$property} = $self->{field_defaults}->{$property};
}


######################################################################
=pod

=item $newfield = $field->clone

Clone the field, so the clone can be edited without affecting the
original. Does not deep copy properties which are references - these
should be set to new values, rather than the contents altered. Eg.
don't push to a cloned options list, replace it.

=cut
######################################################################

sub clone
{
	my( $self ) = @_;

	return EPrints::MetaField->new( %{$self} );
}




######################################################################
=pod

=item $dataset = $field->get_dataset

Return the dataset to which this field belongs, or undef.

=cut
######################################################################

sub get_dataset
{
	my( $self ) = @_;

	return $self->{dataset};
}

######################################################################
=pod

=item $xhtml = $field->render_name( $handle )

Render the name of this field as an XHTML object.

=cut
######################################################################

sub render_name
{
	my( $self, $handle ) = @_;

	if( defined $self->{title_xhtml} )
	{
		return $self->{title_xhtml};
	}
	my $phrasename = $self->{confid}."_fieldname_".$self->{name};

	return $handle->html_phrase( $phrasename );
}

######################################################################
=pod

=item $xhtml = $field->render_help( $handle )

Return the help information for a user inputing some data for this
field as an XHTML chunk.

=cut
######################################################################

sub render_help
{
	my( $self, $handle ) = @_;

	if( defined $self->{help_xhtml} )
	{
		return $self->{help_xhtml};
	}
	my $phrasename = $self->{confid}."_fieldhelp_".$self->{name};

	return $handle->html_phrase( $phrasename );
}


######################################################################
=pod

=item $xhtml = $field->render_input_field( $handle, $value, [$dataset], [$staff], [$hidden_fields], $obj, [$prefix] )

Return the XHTML of the fields for an form which will allow a user
to input metadata to this field. $value is the default value for
this field.

The actual function called may be overridden from the config options.

=cut
######################################################################

sub render_input_field
{
	my( $self, $handle, $value, $dataset, $staff, $hidden_fields, $obj, $prefix ) = @_;

	my $basename;
	if( defined $prefix )
	{
		$basename = $prefix."_".$self->{name};
	}
	else
	{
		$basename = $self->{name};
	}

	if( defined $self->{toform} )
	{
		$value = $self->call_property( "toform", $value, $handle );
	}

	if( defined $self->{render_input} )
	{
		return $self->call_property( "render_input",
			$self,
			$handle, 
			$value, 
			$dataset, 
			$staff,
			$hidden_fields,
			$obj,
			$basename );
	}

	return $self->render_input_field_actual( 
			$handle, 
			$value, 
			$dataset, 
			$staff,
			$hidden_fields,
			$obj,
			$basename );
}


######################################################################
=pod

=item $value = $field->form_value( $handle, $object, [$prefix] )

Get a value for this field from the CGI parameters, assuming that
the form contained the input fields for this metadata field.

=cut
######################################################################

sub form_value
{
	my( $self, $handle, $object, $prefix ) = @_;

	my $basename;
	if( defined $prefix )
	{
		$basename = $prefix."_".$self->{name};
	}
	else
	{
		$basename = $self->{name};
	}

	my $value = $self->form_value_actual( $handle, $object, $basename );

	if( defined $self->{fromform} )
	{
		$value = $self->call_property( "fromform", $value, $handle, $object, $basename );
	}

	return $value;
}


######################################################################
=pod

=item $name = $field->get_name

Return the name of this field.

=cut
######################################################################

sub get_name
{
	my( $self ) = @_;
	return $self->{name};
}


######################################################################
=pod

=item $type = $field->get_type

Return the type of this field.

=cut
######################################################################

sub get_type
{
	my( $self ) = @_;
	return $self->{type};
}



######################################################################
=pod

=item $value = $field->get_property( $property )

Return the value of the given property.

Special note about "required" property, the workflow may in some
situations return a field which is 'required' which isn't if you
get it via $dataset.

There's about 50 in total, with additional extras for some subtypes
of MetaField! However the most useful ones are:

	if( $field->get_property( "multiple" ) ) { ... }
	if( $field->get_property( "required" ) ) { ... }

=cut
######################################################################

sub get_property
{
	my( $self, $property ) = @_;

	if( !defined $self->{field_defaults}->{$property} )
	{
		EPrints::abort( <<END );
BAD METAFIELD get_property property name: "$property"
Field: $self->{name}, type: $self->{type}
END
	}

	return( $self->{$property} ); 
} 


######################################################################
=pod

=item $boolean = $field->is_type( @typenames )

Return true if the type of this field is one of @typenames.

=cut
######################################################################

sub is_type
{
	my( $self , @typenames ) = @_;

	foreach( @typenames )
	{
		return 1 if( $self->{type} eq $_ );
	}
	return 0;
}





######################################################################
=pod

=item $xhtml = $field->render_value( $handle, $value, [$alllangs], [$nolink], $object )

Render the given value of this given string as XHTML DOM. If $alllangs 
is true and this is a multilang field then render all language versions,
not just the current language (for editorial checking). If $nolink is
true then don't make this field a link, for example subject fields 
might otherwise link to the subject view page.

If render_value or render_single_value properties are set then these
control the rendering instead.

=cut
######################################################################

sub render_value
{
	my( $self, $handle, $value, $alllangs, $nolink, $object ) = @_;

	if( defined $self->{render_value} )
	{
		return $self->call_property( "render_value", 
			$handle, 
			$self, 
			$value, 
			$alllangs, 
			$nolink,
			$object );
	}

	return $self->render_value_actual( $handle, $value, $alllangs, $nolink, $object );
}

sub render_value_actual
{
	my( $self, $handle, $value, $alllangs, $nolink, $object ) = @_;

	unless( EPrints::Utils::is_set( $value ) )
	{
		if( $self->{render_quiet} )
		{
			return $handle->make_doc_fragment;
		}
		else
		{
			# maybe should just return nothing
			return $handle->html_phrase( 
				"lib/metafield:unspecified",
				fieldname => $self->render_name( $handle ) );
		}
	}

	unless( $self->get_property( "multiple" ) )
	{
		return $self->render_value_no_multiple( 
			$handle, 
			$value, 
			$alllangs, 
			$nolink,
			$object );
	}

	my @rendered_values = ();

	my $first = 1;
	my $html = $handle->make_doc_fragment();
	
	for(my $i=0; $i<scalar(@$value); ++$i )
	{
		my $sv = $value->[$i];
		unless( $i == 0 )
		{
			my $phrase = "lib/metafield:join_".$self->get_type;
			my $basephrase = $phrase;
			if( $i == 1 && $handle->get_lang->has_phrase( 
						$basephrase.".first", $handle ) ) 
			{ 
				$phrase = $basephrase.".first";
			}
			if( $i == scalar(@$value)-1 && 
					$handle->get_lang->has_phrase( 
						$basephrase.".last", $handle ) ) 
			{ 
				$phrase = $basephrase.".last";
			}
			$html->appendChild( $handle->html_phrase( $phrase ) );
		}
		$html->appendChild( 
			$self->render_value_no_multiple( 
				$handle, 
				$sv, 
				$alllangs, 
				$nolink,
				$object ) );
	}
	return $html;

}


######################################################################
# $xhtml = $field->render_value_no_multiple( $handle, $value, $alllangs, $nolink, $object )
# 
# Render the XHTML for a non-multiple value. Can be either a from
# a non-multiple field, or a single value from a multiple field.
######################################################################

sub render_value_no_multiple
{
	my( $self, $handle, $value, $alllangs, $nolink, $object ) = @_;


	my $rendered = $self->render_value_withopts( $handle, $value, $nolink, $object );

	if( !defined $self->{browse_link} || $nolink)
	{
		return $rendered;
	}

	my $url = $handle->get_repository->get_conf(
			"http_url" );
	my $views = $handle->get_repository->get_conf( "browse_views" );
	my $linkview;
	foreach my $view ( @{$views} )
	{
		if( $view->{id} eq $self->{browse_link} )
		{
			$linkview = $view;
		}
	}

	if( !defined $linkview )
	{
		$handle->get_repository->log( "browse_link to view '".$self->{browse_link}."' not found for field '".$self->{name}."'\n" );
		return $rendered;
	}

	my $link_id = $self->get_id_from_value( $handle, $value );

	if( defined $linkview->{fields} && $linkview->{fields} =~ m/,/ )
	{
		# has sub pages
		$url .= "/view/".$self->{browse_link}."/".
			EPrints::Utils::escape_filename( $link_id )."/";
	}
	else
	{
		# no sub pages
		$url .= "/view/".$self->{browse_link}."/".
			EPrints::Utils::escape_filename( $link_id ).
			".html";
	}

	my $a = $handle->render_link( $url );
	$a->appendChild( $rendered );
	return $a;
}


######################################################################
# $xhtml = $field->render_value_withopts( $handle, $value, $nolink, $object )
# 
# Render a single value but adding the render_opts features.
# 
# This uses either the field specific render_single_value or, if one
# is configured, the render_single_value specified in the config.
# 
# Usually just used internally.
######################################################################

sub render_value_withopts
{
	my( $self, $handle, $value, $nolink, $object ) = @_;

	if( !EPrints::Utils::is_set( $value ) )
	{
		return $handle->html_phrase( 
			"lib/metafield:unspecified",
			fieldname => $self->render_name( $handle ) );
	}

	if( $self->{render_magicstop} )
	{
		# add a full stop if the vale does not end with ? ! or .
		$value =~ s/\s*$//;
		if( $value !~ m/[\?!\.]$/ )
		{
			$value .= '.';
		}
	}

	if( $self->{render_noreturn} )
	{
		# turn  all CR's and LF's to spaces
		$value =~ s/[\r\n]/ /g;
	}

	if( defined $self->{render_single_value} )
	{
		return $self->call_property( "render_single_value",
			$handle, 
			$self, 
			$value,
			$object );
	}

	return $self->render_single_value( $handle, $value, $object );
}


######################################################################
=pod

=item $out_list = $field->sort_values( $handle, $in_list )

Sorts the in_list into order, based on the "order values" of the 
values in the in_list. Assumes that the values are not a list of
multiple values. [ [], [], [] ], but rather a list of single values.

=cut
######################################################################

sub sort_values
{
	my( $self, $handle, $in_list ) = @_;

	return $handle->get_database->sort_values( $self, $in_list );
}


######################################################################
# @values = $field->list_values( $value )
#
# Return a list of every distinct value in this field. 
# 
# - for simple fields: return ( $value )
# - for multiple fields: return @{$value}
# 
# This function is used by the item_matches method in Search. It's useful
# when you want a list of values and don't care if the source is multiple 
# or not.
######################################################################

sub list_values
{
	my( $self, $value ) = @_;

	if( !EPrints::Utils::is_set( $value ) )
	{
		return ();
	}

	if( $self->get_property( "multiple" ) )
	{
		return @{$value};
	}

	return $value;
}



######################################################################
# $value = $field->most_local( $handle, $value )
# 
# If this field is a multilang field then return the version of the 
# value most useful for the language of the session. In order of
# preference: The language of the session, the default language for
# the repository, any language at all. If it is not a multilang field
# then just return $value.
######################################################################

sub most_local
{
	my( $self, $handle, $value ) = @_;

	my $bestvalue =  EPrints::Handle::best_language( 
		$handle->get_repository, $handle->get_langid(), %{$value} );
	return $bestvalue;
}



######################################################################
=pod

=item $value2 = $field->call_property( $property, @args )

Call the method described by $property. Pass it the arguments and
return the result.

The property may contain either a code reference, or the scalar name
of a method.

=cut
######################################################################

sub call_property
{
	my( $self, $property, @args ) = @_;

	my $v = $self->{$property};

	return unless defined $v;

	if( ref( $v ) eq "CODE" || $v =~ m/::/ )
	{
		no strict 'refs';
		return &{$v}(@args);
	}	

	return $self->{repository}->call( $v, @args );
}

######################################################################
# $val = $field->value_from_sql_row( $handle, $row )
# 
# Shift and return the value of this field from the database input $row.
# Clever for fields with multiple columns per row.
######################################################################

sub value_from_sql_row
{
	my( $self, $handle, $row ) = @_;

	return shift @$row;
}

######################################################################
# @row = $field->sql_row_from_value( $handle, $value )
# 
# Return a list of values to insert into the database based on $value.
######################################################################

sub sql_row_from_value
{
	my( $self, $handle, $value ) = @_;

	return( $value );
}

######################################################################
# %opts = $field->get_sql_properties( $handle )
# 
# Map the relevant SQL properties for this field to options passed to 
# L<EPrints::Database>::get_column_type().
######################################################################

sub get_sql_properties
{
	my( $self, $handle ) = @_;

	return (
		index => $self->{ "sql_index" },
		langid => $self->{ "sql_langid" },
		sorted => $self->{ "sql_sorted" },
	);
}

######################################################################
# @types = $field->get_sql_type( $handle )
# 
# Return the SQL column types of this field, used for creating tables.
######################################################################

sub get_sql_type
{
	my( $self, $handle ) = @_;

	my $database = $handle->get_database;

	return $database->get_column_type(
		$self->get_sql_name,
		EPrints::Database::SQL_VARCHAR,
		!$self->get_property( "allow_null" ),
		$self->get_property( "maxlength" ),
		undef, # precision
		$self->get_sql_properties,
	);
}

######################################################################
# $field = $field->create_ordervalues_field( $handle [, $langid ] )
# 
# Return a new field object that this field can use to store order values, 
# optionally for language $langid.
######################################################################

sub create_ordervalues_field
{
	my( $self, $handle, $langid ) = @_;

	return EPrints::MetaField->new(
		repository => $handle->get_repository,
		type => "longtext",
		name => $self->get_name,
		sql_sorted => 1,
		sql_langid => $langid,
	);
}

######################################################################
# $sql = $field->get_sql_index
# 
# Return the columns that an index should be created over.
######################################################################

sub get_sql_index
{
	my( $self ) = @_;
	
	return () unless( $self->get_property( "sql_index" ) );

	return $self->get_sql_names;
}


######################################################################
=pod

=item $xhtml_dom = $field->render_single_value( $handle, $value )

Returns the XHTML representation of the value. If the field is multiple
then $value should be a single item from the values, not the list.

=cut
######################################################################

sub render_single_value
{
	my( $self, $handle, $value ) = @_;

	return $handle->make_text( $value );
}


######################################################################
# $xhtml = $field->render_input_field_actual( $handle, $value, [$dataset], [$staff], [$hidden_fields], [$obj], [$basename] )
# 
# Return the XHTML of the fields for an form which will allow a user
# to input metadata to this field. $value is the default value for
# this field.
# 
# Unlike render_input_field, this function does not use the render_input
# property, even if it's set.
# 
# The $obj is the current state of the object this field is associated 
# with, if any.
######################################################################

sub render_input_field_actual
{
	my( $self, $handle, $value, $dataset, $staff, $hidden_fields, $obj, $basename ) = @_;


	my $elements = $self->get_input_elements( $handle, $value, $staff, $obj, $basename );

	# if there's only one element then lets not bother making
	# a table to put it in

#	if( scalar @{$elements} == 1 && scalar @{$elements->[0]} == 1 )
#	{
#		return $elements->[0]->[0]->{el};
#	}

	my $table = $handle->make_element( "table", border=>0, cellpadding=>0, cellspacing=>0, class=>"ep_form_input_grid" );

	my $col_titles = $self->get_input_col_titles( $handle, $staff );
	if( defined $col_titles )
	{
		my $tr = $handle->make_element( "tr" );
		my $th;
		my $x = 0;
		if( $self->get_property( "multiple" ) && $self->{input_ordered})
		{
			$th = $handle->make_element( "th", class=>"empty_heading", id=>$basename."_th_".$x++ );
			$tr->appendChild( $th );
		}

		if( !defined $col_titles )
		{
			$th = $handle->make_element( "th", class=>"empty_heading", id=>$basename."_th_".$x++ );
			$tr->appendChild( $th );
		}	
		else
		{
			foreach my $col_title ( @{$col_titles} )
			{
				$th = $handle->make_element( "th", id=>$basename."_th_".$x++ );
				$th->appendChild( $col_title );
				$tr->appendChild( $th );
			}
		}
		$table->appendChild( $tr );
	}

	my $y = 0;
	foreach my $row ( @{$elements} )
	{
		my $x = 0;
		my $tr = $handle->make_element( "tr" );
		foreach my $item ( @{$row} )
		{
			my %opts = ( valign=>"top", id=>$basename."_cell_".$x++."_".$y );
			foreach my $prop ( keys %{$item} )
			{
				next if( $prop eq "el" );
				$opts{$prop} = $item->{$prop};
			}	
			my $td = $handle->make_element( "td", %opts );
			if( defined $item->{el} )
			{
				$td->appendChild( $item->{el} );
			}
			$tr->appendChild( $td );
		}
		$table->appendChild( $tr );
		$y++;
	}

	return $table;
}

sub get_input_col_titles
{
	my( $self, $handle, $staff ) = @_;
	return undef;
}


sub get_input_elements
{
	my( $self, $handle, $value, $staff, $obj, $basename ) = @_;	

	my $assist;
	if( $self->{input_assist} )
	{
		$assist = $handle->make_doc_fragment;
		$assist->appendChild( $handle->render_internal_buttons(
			$self->{name}."_assist" => 
				$handle->phrase( 
					"lib/metafield:assist" ) ) );
	}

	unless( $self->get_property( "multiple" ) )
	{
		my $rows = $self->get_input_elements_single( 
				$handle, 
				$value,
				$basename,
				$staff,
				$obj );
		if( defined $self->{input_advice_right} )
		{
			my $advice = $self->call_property( "input_advice_right", $handle, $self, $value );
			my $row = pop @{$rows};
			push @{$row}, { el=>$advice };
			push @{$rows}, $row;
		}


		my $cols = scalar @{$rows->[0]};
		if( defined $self->{input_lookup_url} )
		{
			my $n = length( $basename) - length( $self->{name}) - 1;
			my $componentid = substr( $basename, 0, $n );
			my $lookup = $handle->make_doc_fragment;
			my $drop_div = $handle->make_element( "div", id=>$basename."_drop", class=>"ep_drop_target" );
			$lookup->appendChild( $drop_div );
			my $drop_loading_div = $handle->make_element( "div", id=>$basename."_drop_loading", class=>"ep_drop_loading", style=>"display: none" );
			$drop_loading_div->appendChild( $handle->html_phrase( "lib/metafield:drop_loading" ) );
			$lookup->appendChild( $drop_loading_div );

			my @ids = $self->get_basic_input_ids($handle, $basename, $staff, $obj );
			my $extra_params = $self->{input_lookup_params};
			if( defined $extra_params ) 
			{
				$extra_params = "&$extra_params";
			}
			else
			{
				$extra_params = "";
			}
			my @code;
			foreach my $id ( @ids )
			{	
				my @wcells = ( $id );
				push @code, 'ep_autocompleter( "'.$id.'", "'.$basename.'_drop", "'.$self->{input_lookup_url}.'", {relative: "'.$basename.'", component: "'.$componentid.'" }, [ $("'.join('"),$("',@wcells).'")], [], "'.$extra_params.'" );'."\n";
			}
			my $script = $handle->make_javascript( join "", @code );
			$lookup->appendChild( $script );
			push @{$rows}, [ {el=>$lookup,colspan=>$cols,class=>"ep_form_input_grid_wide"} ];
		}
		if( defined $self->{input_advice_below} )
		{
			my $advice = $self->call_property( "input_advice_below", $handle, $self, $value );
			push @{$rows}, [ {el=>$advice,colspan=>$cols,class=>"ep_form_input_grid_wide"} ];
		}

		if( defined $assist )
		{
			push @{$rows}, [ {el=>$assist,colspan=>3,class=>"ep_form_input_grid_wide"} ];
		}
		return $rows;
	}

	# multiple field...

	my $boxcount = $handle->param( $self->{name}."_spaces" );
	if( !defined $boxcount )
	{
		$boxcount = $self->{input_boxes};
	}
	$value = [] if( !defined $value );
	my $cnt = scalar @{$value};
	#cjg hack hack hack
	if( $boxcount<=$cnt )
	{
		if( $self->{name} eq "editperms" )
		{
			$boxcount = $cnt;
		}	
		else
		{
			$boxcount = $cnt+$self->{input_add_boxes};
		}
	}

	my $swap = $handle->param( $self->{name}."_swap" );
	if( $swap =~ m/^(\d+),(\d+)$/ )
	{
		my( $a, $b ) = ( $value->[$1-1], $value->[$2-1] );
		( $value->[$1-1], $value->[$2-1] ) = ( $b, $a );
		# If the last item was moved down then extend boxcount by 1
		$boxcount++ if( $2 == $boxcount ); 
	}


	my $imagesurl = $handle->get_repository->get_conf( "rel_path" )."/style/images";
	
	my $rows = [];
	for( my $i=1 ; $i<=$boxcount ; ++$i )
	{
		my $section = $self->get_input_elements_single( 
				$handle, 
				$value->[$i-1], 
				$basename."_".$i,
				$staff,
				$obj );
		my $first = 1;
		for my $n (0..(scalar @{$section})-1)
		{
			my $row =  [  @{$section->[$n]} ];
			my $col1 = {};
			my $lastcol = {};
			if( $n == 0 && $self->{input_ordered})
			{
				$col1 = { el=>$handle->make_text( $i.". " ), class=>"ep_form_input_grid_pos" };
				my $arrows = $handle->make_doc_fragment;
				$arrows->appendChild( $handle->make_element(
					"input",
					type=>"image",
					src=> "$imagesurl/multi_down.png",
					alt=>"down",
					title=>"move down",
               				name=>"_internal_".$self->{name}."_down_$i",
					value=>"1" ));
				if( $i > 1 )
				{
					$arrows->appendChild( $handle->make_text( " " ) );
					$arrows->appendChild( $handle->make_element(
						"input",
						type=>"image",
						alt=>"up",
						title=>"move up",
						src=> "$imagesurl/multi_up.png",
                				name=>"_internal_".$self->{name}."_up_$i",
						value=>"1" ));
				}
				$lastcol = { el=>$arrows, valign=>"middle", class=>"ep_form_input_grid_arrows" };
				$row =  [ $col1, @{$section->[$n]}, $lastcol ];
			}
			if( defined $self->{input_advice_right} )
			{
				my $advice = $self->call_property( "input_advice_right", $handle, $self, $value->[$i-1] );
				push @{$row}, { el=>$advice };
			}
			push @{$rows}, $row;

			# additional rows
			my $y = scalar @{$rows}-1;
			my $cols = scalar @{$row};
			if( defined $self->{input_lookup_url} )
			{
				my $n = length( $basename) - length( $self->{name}) - 1;
				my $componentid = substr( $basename, 0, $n );
				my $ibasename = $basename."_".$i;
				my $lookup = $handle->make_doc_fragment;
				my $drop_div = $handle->make_element( "div", id=>$ibasename."_drop", class=>"ep_drop_target" );
				$lookup->appendChild( $drop_div );
				my $drop_loading_div = $handle->make_element( "div", id=>$ibasename."_drop_loading", class=>"ep_drop_loading", style=>"display: none" );
				$drop_loading_div->appendChild( $handle->html_phrase( "lib/metafield:drop_loading" ) );
				$lookup->appendChild( $drop_loading_div );
				my @ids = $self->get_basic_input_ids( $handle, $ibasename, $staff, $obj );
				my $extra_params = $self->{input_lookup_params};
				if( defined $extra_params ) 
				{
					$extra_params = "&$extra_params";
				}
				else
				{
					$extra_params = "";
				}
				my @code;
				foreach my $id ( @ids )
				{	
					my @wcells = ();
					for( 1..scalar(@{$row})-2 ) { push @wcells, $basename."_cell_".$_."_".$y; }
					my @relfields = ();
					foreach ( @ids )
					{
						my $id2 = $_; # prevent changing it!
						$id2=~s/^$ibasename//;
						push @relfields, $id2;
					}
					push @code, 'ep_autocompleter( "'.$id.'", "'.$ibasename.'_drop", "'.$self->{input_lookup_url}.'", { relative: "'.$ibasename.'", component: "'.$componentid.'" }, [$("'.join('"),$("',@wcells).'")], [ "'.join('","',@relfields).'"],"'.$extra_params.'" );'."\n";
				}
				my $script = $handle->make_javascript( join "", @code );
				$lookup->appendChild( $script );
				my @row = ();
				push @row, {} if( $self->{input_ordered} );
				push @row, {el=>$lookup,colspan=>$cols-1, class=>"ep_form_input_grid_wide"};
				push @{$rows}, \@row;
			#, {afterUpdateElement: updated}); " ));
			}
			if( defined $self->{input_advice_below} )
			{
				my $advice = $self->call_property( "input_advice_below", $handle, $self, $value->[$i-1] );
				push @{$rows}, [ {},{el=>$advice,colspan=>$cols-1, class=>"ep_form_input_grid_wide"} ];
			}
		}
	}
	my $more = $handle->make_doc_fragment;
	$more->appendChild( $handle->render_hidden_field(
					$self->{name}."_spaces",
					$boxcount ) );
	$more->appendChild( $handle->render_internal_buttons(
		$self->{name}."_morespaces" => 
			$handle->phrase( 
				"lib/metafield:more_spaces" ) ) );
	if( defined $assist )
	{
		$more->appendChild( $assist );
	}

	my @row = ();
	push @row, {} if( $self->{input_ordered} );
	push @row, {el=>$more,colspan=>3,class=>"ep_form_input_grid_wide"};
	push @{$rows}, \@row;

	return $rows;
}



sub get_state_params
{
	my( $self, $handle, $prefix ) = @_;

	my $params = "";
	my $jump = "";

	my $ibutton = $handle->get_internal_button;
	my $name = $self->{name};
	if( $ibutton eq "${name}_morespaces" ) 
	{
		my $spaces = $handle->param( $self->{name}."_spaces" );
		$spaces += $self->{input_add_boxes};
		$params.= "&".$self->{name}."_spaces=$spaces";
		$jump = "#".$self->{name};
	}
	my $ndown = $name."_down_";
	if( $ibutton =~ m/^$ndown(\d+)$/ )
	{
		$params.= "&".$self->{name}."_swap=$1,".($1+1);
		$jump = "#".$self->{name};
	}
	my $nup = $name."_up_";
	if( $ibutton =~ m/^$nup(\d+)$/ )
	{
		$params.= "&".$self->{name}."_swap=".($1-1).",$1";
		$jump = "#".$self->{name};
	}

	return $params.$jump;	
}





sub get_input_elements_single
{
	my( $self, $handle, $value, $basename, $staff, $obj ) = @_;

	return $self->get_basic_input_elements( 
			$handle, 
			$value, 
			$basename, 
			$staff,
			$obj );
}	



sub get_basic_input_elements
{
	my( $self, $handle, $value, $basename, $staff, $obj ) = @_;

	my $maxlength = $self->get_max_input_size;
	my $size = ( $maxlength > $self->{input_cols} ?
					$self->{input_cols} : 
					$maxlength );


	my $f = $handle->make_element( "div" );
	my $input = $handle->render_noenter_input_field(
		class=>"ep_form_text",
		name => $basename,
		id => $basename,
		value => $value,
		size => $size,
		maxlength => $maxlength );
	$f->appendChild( $input );
	$f->appendChild( $handle->make_element( "div", id=>$basename."_".$_."_billboard" ));

	return [ [ { el=>$f } ] ];
}

# array of all the ids of input fields

sub get_basic_input_ids
{
	my( $self, $handle, $basename, $staff, $obj ) = @_;

	return( $basename );
}

sub get_max_input_size
{
	return $EPrints::MetaField::VARCHAR_SIZE;
}





######################################################################
# 
# $foo = $field->form_value_actual( $handle, $object, $basename )
#
# undocumented
#
######################################################################

sub form_value_actual
{
	my( $self, $handle, $object, $basename ) = @_;

	if( $self->get_property( "multiple" ) )
	{
		my @values = ();
		my $boxcount = $handle->param( $self->{name}."_spaces" );
		$boxcount = 1 if( $boxcount < 1 );
		for( my $i=1; $i<=$boxcount; ++$i )
		{
			my $value = $self->form_value_single( $handle, $basename."_".$i, $object );
			next unless( EPrints::Utils::is_set( $value ) );
			push @values, $value;
		}
		if( scalar @values == 0 )
		{
			return undef;
		}
		return \@values;
	}

	return $self->form_value_single( $handle, $basename, $object );
}

######################################################################
# 
# $foo = $field->form_value_single( $handle, $n, $object )
#
# undocumented
#
######################################################################

sub form_value_single
{
	my( $self, $handle, $basename, $object ) = @_;

	my $value = $self->form_value_basic( $handle, $basename, $object );
	return undef unless( EPrints::Utils::is_set( $value ) );
	return $value;
}

######################################################################
# 
# $foo = $field->form_value_basic( $handle, $basename, $object )
#
# undocumented
#
######################################################################

sub form_value_basic
{
	my( $self, $handle, $basename, $object ) = @_;
	
	my $value = $handle->param( $basename );

	return undef if( !EPrints::Utils::is_set( $value ) );

	# strip line breaks (turn them to "space")
	$value=~s/[\n\r]+/ /gs;

	return $value;
}

######################################################################
# @sqlnames = $field->get_sql_names
# 
# Return the names of this field's columns as they appear in a SQL table.
######################################################################

sub get_sql_names
{
	my( $self ) = @_;

	return( $self->{name} );
}

# Utility/backwards compatibility
sub get_sql_name
{
	my( $self ) = @_;

	return $self->{ name };
}

######################################################################
# $boolean = $field->is_browsable
# 
# Return true if this field can be "browsed". ie. Used as a view.
######################################################################

sub is_browsable
{
	return( 1 );
}


######################################################################
=pod

=item $values = $field->get_values( $handle, $dataset, %opts )

Return a reference to an array of all the values of this field. 

For fields like "subject" or "set" it returns all the variations. 

For fields like "text" return all the distinct values from the database.

Results are sorted according to the ordervalues of the $handle.

=cut
######################################################################

sub get_values
{
	my( $self, $handle, $dataset, %opts ) = @_;

	my $langid = $opts{langid};
	$langid = $handle->get_langid unless( defined $langid );

	my $unsorted_values = $self->get_unsorted_values( 
		$handle,
		$dataset,	
		%opts );

	my %orderkeys = ();
	my @values;
	foreach my $value ( @{$unsorted_values} )
	{
		my $v2 = $value;
		$v2 = "" unless( defined $value );
		push @values, $v2;

		# uses function _basic because value will NEVER be multiple
		my $orderkey = $self->ordervalue_basic(
			$value, 
			$handle, 
			$langid );
		$orderkeys{$v2} = $orderkey || "";
	}

	my @outvalues = sort {$orderkeys{$a} cmp $orderkeys{$b}} @values;

	return \@outvalues;
}

sub get_unsorted_values
{
	my( $self, $handle, $dataset, %opts ) = @_;

	return $handle->get_database->get_values( $self, $dataset );
}

sub get_ids_by_value
{
	my( $self, $handle, $dataset, %opts ) = @_;

	return $handle->get_database->get_ids_by_field_values( $self, $dataset, %opts );
}

######################################################################
# $id = $field->get_id_from_value( $handle, $value )
# 
# Returns a unique id for $value or "NULL" if $value is undefined.
######################################################################

sub get_id_from_value
{
	my( $self, $handle, $value ) = @_;

	return defined($value) ? $value : "NULL";
}

######################################################################
# $value = $field->get_value_from_id( $handle, $id )
# 
# Returns the value from $id or undef if $id is "NULL".
######################################################################

sub get_value_from_id
{
	my( $self, $handle, $id ) = @_;

	return $id eq "NULL" ? undef : $id;
}

######################################################################
=pod

=item $xhtml = $field->get_value_label( $handle, $value )

Return an XHTML DOM object describing the given value. Normally this
is just the value, but in the case of something like a "set" field 
this returns the name of the option in the current language.

=cut
######################################################################

sub get_value_label
{
	my( $self, $handle, $value ) = @_;

	return $handle->make_text( $value );
}

######################################################################
# $ov = $field->ordervalue( $value, $handle, $langid, $dataset )
# 
# Return a string representing this value which can be used to sort
# it into order by comparing it alphabetically.
######################################################################

sub ordervalue
{
	my( $self , $value , $handle , $langid , $dataset ) = @_;

	return "" if( !defined $value );

	if( defined $self->{make_value_orderkey} )
	{
		no strict "refs";
		return $self->call_property( "make_value_orderkey",
			$self, 
			$value, 
			$handle, 
			$langid,
			$dataset );
	}


	if( !$self->get_property( "multiple" ) )
	{
		return $self->ordervalue_single( $value , $handle , $langid, $dataset );
	}

	my @r = ();	
	foreach( @$value )
	{
		push @r, $self->ordervalue_single( $_ , $handle , $langid, $dataset );
	}
	return join( ":", @r );
}


######################################################################
# 
# $ov = $field->ordervalue_single( $value, $handle, $langid, $dataset )
# 
# undocumented
# 
######################################################################

sub ordervalue_single
{
	my( $self , $value , $handle , $langid, $dataset ) = @_;

	return "" unless( EPrints::Utils::is_set( $value ) );

	if( defined $self->{make_single_value_orderkey} )
	{
		return $self->call_property( "make_single_value_orderkey",
			$self, 
			$value, 
			$dataset ); 
	}

	return $self->ordervalue_basic( $value, $handle, $langid );
}


######################################################################
# 
# $ov = $field->ordervalue_basic( $value )
# 
# undocumented
# 
######################################################################

sub ordervalue_basic
{
	my( $self, $value, $handle, $langid ) = @_;

	return $value;
}







# XML output methods


sub to_xml
{
	my( $self, $handle, $value, $dataset, %opts ) = @_;

	# we're part of a compound field that will include our value
	if( defined $self->{parent_name} )
	{
		return $handle->make_doc_fragment;
	}

	# don't show empty fields
	if( !$opts{show_empty} && !EPrints::Utils::is_set( $value ) )
	{
		return $handle->make_doc_fragment;
	}

	my $tag = $handle->make_element( $self->get_name );	
	if( $self->get_property( "multiple" ) )
	{
		foreach my $single ( @{$value} )
		{
			my $item = $handle->make_element( "item" );
			$item->appendChild( $self->to_xml_basic( $handle, $single, $dataset, %opts ) );
			$tag->appendChild( $item );
		}
	}
	else
	{
		$tag->appendChild( $self->to_xml_basic( $handle, $value, $dataset, %opts ) );
	}

	return $tag;
}

sub to_xml_basic
{
	my( $self, $handle, $value, $dataset, %opts ) = @_;

	if( !defined $value ) 
	{
		return $handle->make_text( "" );
	}
	return $handle->make_text( $value );
}

######################################################################
# $epdata = $field->xml_to_epdata( $handle, $xml, %opts )
# 
# Populates $epdata based on $xml.
######################################################################

sub xml_to_epdata
{
	my( $self, $handle, $xml, %opts ) = @_;

	my $value = undef;

	if( $self->get_property( "multiple" ) )
	{
		$value = [];
		foreach my $node ($xml->childNodes)
		{
			next unless EPrints::XML::is_dom( $node, "Element" );
			if( $node->nodeName ne "item" )
			{
				if( defined $opts{Handler} )
				{
					$opts{Handler}->message( "warning", $handle->html_phrase( "Plugin/Import/XML:unexpected_element", name => $handle->make_text( $node->nodeName ) ) );
					$opts{Handler}->message( "warning", $handle->html_phrase( "Plugin/Import/XML:expected", elements => $handle->make_text( "<item>" ) ) );
				}
				next;
			}
			push @$value, $self->xml_to_epdata_basic( $handle, $node, %opts );
		}
	}
	else
	{
		$value = $self->xml_to_epdata_basic( $handle, $xml, %opts );
	}

	return $value;
}

######################################################################
# return epdata for a single value of this field
######################################################################

sub xml_to_epdata_basic
{
	my( $self, $handle, $xml, %opts ) = @_;

	return EPrints::Utils::tree_to_utf8( scalar $xml->childNodes );
}




#### old xml v1

sub to_xml_old
{
	my( $self, $handle, $v, $no_xmlns ) = @_;

	my $r = $handle->make_doc_fragment;

	if( $self->is_virtual )
	{
		return $r;
	}

	if( $self->get_property( "multiple" ) )
	{
		my @list = @{$v};
		# trim empty elements at end
		while( scalar @list > 0 && !EPrints::Utils::is_set($list[(scalar @list)-1]) )
		{
			pop @list;
		}
		foreach my $item ( @list )
		{
			$r->appendChild( $handle->make_text( "    " ) );
			$r->appendChild( $self->to_xml_old_single( $handle, $item, $no_xmlns ) );
			$r->appendChild( $handle->make_text( "\n" ) );
		}
	}
	else
	{
		$r->appendChild( $handle->make_text( "    " ) );
		$r->appendChild( $self->to_xml_old_single( $handle, $v, $no_xmlns ) );
		$r->appendChild( $handle->make_text( "\n" ) );
	}
	return $r;
}

sub to_xml_old_single
{
	my( $self, $handle, $v, $no_xmlns ) = @_;

	my %attrs = ( name=>$self->get_name() );
	$attrs{'xmlns'}="http://eprints.org/ep2/data" unless( $no_xmlns );

	my $r = $handle->make_element( "field", %attrs );

	$r->appendChild( $self->to_xml_basic( $handle, $v ) );

	return $r;
}

########## end of old XML

sub render_xml_schema
{
	my( $self, $handle ) = @_;

	my $element = $handle->make_element( "xs:element", name => $self->get_name );

	my $phraseid = $self->{dataset}->confid . "_fieldname_" . $self->get_name;
	my $helpid = $self->{dataset}->confid . "_fieldhelp_" . $self->get_name;
	if( $handle->get_lang->has_phrase( $phraseid, $handle ) )
	{
		my $annotation = $handle->make_element( "xs:annotation" );
		$element->appendChild( $annotation );
		my $documentation = $handle->make_element( "xs:documentation" );
		$annotation->appendChild( $documentation );
		$documentation->appendChild( $handle->make_text( "\n" ) );
		$documentation->appendChild( $handle->make_text( $handle->phrase( $phraseid ) ) );
		if( $handle->get_lang->has_phrase( $helpid, $handle ) )
		{
			$documentation->appendChild( $handle->make_text( "\n\n" ) );
			$documentation->appendChild( $handle->make_text( $handle->phrase( $helpid ) ) );
		}
		$documentation->appendChild( $handle->make_text( "\n" ) );
	}

	if( $self->get_property( "multiple" ) )
	{
		my $complexType = $handle->make_element( "xs:complexType" );
		$element->appendChild( $complexType );
		my $sequence = $handle->make_element( "xs:sequence" );
		$complexType->appendChild( $sequence );
		my $item = $handle->make_element( "xs:element", name => "item", type => $self->get_xml_schema_type(), minOccurs => "0", maxOccurs => "unbounded" );
		$sequence->appendChild( $item );
	}
	else
	{
		$element->setAttribute( type => $self->get_xml_schema_type() );
	}

	if( !$self->get_property( "required" ) )
	{
		$element->setAttribute( minOccurs => 0 );
	}

	return $element;
}

sub get_xml_schema_type
{
	my( $self ) = @_;

	return $self->get_property( "type" );
}

sub render_xml_schema_type
{
	my( $self, $handle ) = @_;

	my $type = $handle->make_element( "xs:simpleType", name => $self->get_xml_schema_type );

	my $restriction = $handle->make_element( "xs:restriction", base => "xs:string" );
	$type->appendChild( $restriction );
	my $length = $handle->make_element( "xs:maxLength", value => $self->get_max_input_size );
	$restriction->appendChild( $length );

	return $type;
}

sub render_search_input
{
	my( $self, $handle, $searchfield ) = @_;
	
	my $frag = $handle->make_doc_fragment;

	# complex text types
	my @text_tags = ( "ALL", "ANY" );
	my %text_labels = ( 
		"ANY" => $handle->phrase( "lib/searchfield:text_any" ),
		"ALL" => $handle->phrase( "lib/searchfield:text_all" ) );
	$frag->appendChild( 
		$handle->render_option_list(
			name=>$searchfield->get_form_prefix."_merge",
			values=>\@text_tags,
			default=>$searchfield->get_merge,
			labels=>\%text_labels ) );
	$frag->appendChild( $handle->make_text(" ") );
	$frag->appendChild(
		$handle->render_input_field(
			class => "ep_form_text",
			type => "text",
			name => $searchfield->get_form_prefix,
			value => $searchfield->get_value,
			size => $self->get_property( "search_cols" ),
			maxlength => 256 ) );
	return $frag;
}

sub from_search_form
{
	my( $self, $handle, $basename ) = @_;

	# complex text types

	my $val = $handle->param( $basename );
	return unless defined $val;

	my $search_type = $handle->param( $basename."_merge" );
	my $search_match = $handle->param( $basename."_match" );
		
	# Default search type if none supplied (to allow searches 
	# using simple HTTP GETs)
	$search_type = "ALL" unless defined( $search_type );
	$search_match = "IN" unless defined( $search_match );
		
	return unless( defined $val );

	return( $val, $search_type, $search_match );	
}		


sub render_search_description
{
	my( $self, $handle, $sfname, $value, $merge, $match ) = @_;

	my( $phraseid );
	if( $match eq "EQ" || $match eq "EX" )
	{
		$phraseid = "lib/searchfield:desc_is";
	}
	elsif( $merge eq "ANY" ) # match = "IN"
	{
		$phraseid = "lib/searchfield:desc_any_in";
	}
	else
	{
		$phraseid = "lib/searchfield:desc_all_in";
	}

	my $valuedesc = $self->render_search_value(
		$handle,
		$value );
	
	return $handle->html_phrase(
		$phraseid,
		name => $sfname, 
		value => $valuedesc );
}

sub render_search_value
{
	my( $self, $handle, $value ) = @_;

	return $handle->make_text( '"'.$value.'"' );
}	

sub get_search_group { return 'basic'; } 


# return system defaults for this field type
sub get_property_defaults
{
	return (
		providence => $EPrints::MetaField::FROM_CONFIG,
		allow_null 	=> 1,
		browse_link 	=> $EPrints::MetaField::UNDEF,
		can_clone 	=> 1,
		confid 		=> $EPrints::MetaField::NO_CHANGE,
		export_as_xml 	=> 1,
		fromform 	=> $EPrints::MetaField::UNDEF,
		import		=> 1,
		input_add_boxes => $EPrints::MetaField::FROM_CONFIG,
		input_advice_right => $EPrints::MetaField::UNDEF,
		input_advice_below => $EPrints::MetaField::UNDEF,
		input_assist	=> 0,
		input_boxes 	=> $EPrints::MetaField::FROM_CONFIG,
		input_cols 	=> $EPrints::MetaField::FROM_CONFIG,
		input_lookup_url 	=> $EPrints::MetaField::UNDEF,
		input_lookup_params 	=> $EPrints::MetaField::UNDEF,
		input_ordered 	=> 1,
		make_single_value_orderkey 	=> $EPrints::MetaField::UNDEF,
		make_value_orderkey 		=> $EPrints::MetaField::UNDEF,
		show_in_fieldlist	=> 1,
		maxlength 	=> $EPrints::MetaField::VARCHAR_SIZE,
		multiple 	=> 0,
		name 		=> $EPrints::MetaField::REQUIRED,
		show_in_html	=> 1,
		render_input 	=> $EPrints::MetaField::UNDEF,
		render_single_value 	=> $EPrints::MetaField::UNDEF,
		render_quiet	=> 0,
		render_magicstop	=> 0,
		render_noreturn	=> 0,
		render_dont_link	=> 0,
		render_value 	=> $EPrints::MetaField::UNDEF,
		required 	=> 0,
		requiredlangs 	=> [],
		search_cols 	=> $EPrints::MetaField::FROM_CONFIG,
		sql_index 	=> 1,
		sql_langid 	=> $EPrints::MetaField::UNDEF,
		sql_sorted	=> 0,
		text_index 	=> 0,
		toform 		=> $EPrints::MetaField::UNDEF,
		type 		=> $EPrints::MetaField::REQUIRED,
		sub_name	=> $EPrints::MetaField::UNDEF,
		parent_name	=> $EPrints::MetaField::UNDEF,
		volatile	=> 0,
		virtual		=> 0,
		default_value => $EPrints::MetaField::UNDEF,

		help_xhtml	=> $EPrints::MetaField::UNDEF,
		title_xhtml	=> $EPrints::MetaField::UNDEF,
		join_path	=> $EPrints::MetaField::UNDEF,
);
}

######################################################################
# $value = $field->get_default_value( $handle )
# 
# Return the default value for this field. This is only applicable to very simple
# cases such as timestamps, auto-incremented values etc.
# 
# Any complex initialisation should be done in the "set_eprint_automatic_fields"
# callback (or the equivalent for the given object).
######################################################################

sub get_default_value
{
	my( $self, $handle ) = @_;

	return $self->get_property( "default_value" );
}

######################################################################
# ( $terms, $grep_terms, $ignored ) = $field->get_index_codes( $handle, $value )
# 
# Get indexable terms from $value. $terms is a reference to an array of strings to index. $grep_terms is a reference to an array of terms to add to the grep index. $ignored is a reference to an array of terms that should be ignored (e.g. stop words in a free-text field).
# 
######################################################################

# Most types are not indexed		
sub get_index_codes
{
	my( $self, $handle, $value ) = @_;

	return( [], [], [] );
}

######################################################################
# @terms = $field->split_search_value( $handle, $value )
# 
# Split $value into terms that can be used to search against this field.
######################################################################

sub split_search_value
{
	my( $self, $handle, $value ) = @_;

#	return EPrints::Index::split_words( 
#			$handle,
#			EPrints::Index::apply_mapping( $handle, $value ) );

	return split /\s+/, $value;
}

######################################################################
# $cond = $field->get_search_conditions( $handle, $dataset, $value, $match, $merge, $mode )
# 
# Return a L<Search::Condition> for $value based on this field.
######################################################################

sub get_search_conditions
{
	my( $self, $handle, $dataset, $search_value, $match, $merge,
		$search_mode ) = @_;

	if( $match eq "EX" )
	{
		if( $search_value eq "" )
		{	
			return EPrints::Search::Condition->new( 
					'is_null', 
					$dataset, 
					$self );
		}

		return EPrints::Search::Condition->new( 
				'=', 
				$dataset, 
				$self, 
				$search_value );
	}

	return $self->get_search_conditions_not_ex(
			$handle, 
			$dataset, 
			$search_value, 
			$match, 
			$merge, 
			$search_mode );
}

######################################################################
# $cond = $field->get_search_conditions_not_ex( $handle, $dataset, $value, $match, $merge, $mode )
# 
# Return the search condition for a search which is not-exact ($match ne "EX").
######################################################################

sub get_search_conditions_not_ex
{
	my( $self, $handle, $dataset, $search_value, $match, $merge,
		$search_mode ) = @_;
	
	if( $match eq "EQ" )
	{
		return EPrints::Search::Condition->new( 
			'=', 
			$dataset,
			$self, 
			$search_value );
	}

	# free text!

	# apply stemming and stuff
	my( $codes, $grep_codes, $bad ) = $self->get_index_codes( $handle, $search_value );

	# Just go "yeah" if stemming removed the word
	if( !EPrints::Utils::is_set( $codes->[0] ) )
	{
		return EPrints::Search::Condition->new( "PASS" );
	}

	return EPrints::Search::Condition->new( 
			'index',
 			$dataset,
			$self, 
			$codes->[0] );
}

sub get_value
{
	my( $self, $object ) = @_;

	return $object->get_value_raw( $self->{name} );
}
sub set_value
{
	my( $self, $object, $value ) = @_;

	return $object->set_value_raw( $self->{name},$value );
}

# return true if this is a virtual field which does not exist in the
# database.
sub is_virtual
{
	my( $self ) = @_;
	return $self->{virtual};
}

# if ordering by this field, should we sort highest first?
sub should_reverse_order { return 0; }


# return an array of dom problems
sub validate
{
	my( $self, $handle, $value, $object ) = @_;

	return $handle->get_repository->call(
		"validate_field",
		$self,
		$value,
		$handle );
}



######################################################################

1;

=pod

=back

=cut

