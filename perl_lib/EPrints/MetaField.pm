######################################################################
#
# EPrints::MetaField
#
######################################################################
#
#
######################################################################

=pod

=for Pod2Wiki

=head1 NAME

B<EPrints::MetaField> - A single metadata field.

=head1 SYNOPSIS

my $field = $dataset->field( $fieldname );

$dataset = $field->dataset;

$repo = $field->repository;

$field->set_property( $property, $value );

$value = $field->property( $property );

$name = $field->name;

$type = $field->type;

$xhtml = $field->render_name;

$xhtml = $field->render_help;

$xhtml = $field->render_value_label( $value );

$values = $field->all_values( %opts );

$sorted_list = $field->sort_values( $unsorted_list );


=head1 DESCRIPTION

This object represents a single metadata field, not the value of
that field. A field belongs (usually) to a dataset and has a large
number of properties. Optional and required properties vary between 
types.

"type" is the most important property, it is the type of the metadata
field. For example: "text", "name" or "date".

A full description of metadata types and properties is in the eprints
documentation and will not be duplicated here.

=begin InternalDoc

=head1 PROPERTIES

=over 4

=item provenance => "core" or "config"

Indiciates where the field was initialised from. "core" fields are defined in L<DataObj> classes while "config" fields are defined in cfg.d files.

=item replace_core => 0

Normally any attempt to define two fields with the same name will fail. However, you can replace a core system field by specifying the "replace_core" property. This should be used very carefully!

=back

=end InternalDoc

=head1 METHODS

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

use EPrints::Const qw( :metafield );

use strict;

use Text::Unidecode qw();

$EPrints::MetaField::VARCHAR_SIZE 	= 255;

$EPrints::MetaField::FROM_CONFIG = EP_PROPERTY_FROM_CONFIG;
$EPrints::MetaField::NO_CHANGE   = EP_PROPERTY_NO_CHANGE;
$EPrints::MetaField::REQUIRED    = EP_PROPERTY_REQUIRED;
$EPrints::MetaField::UNDEF       = EP_PROPERTY_UNDEF;

######################################################################
=pod

=begin InternalDoc

=item $field = EPrints::MetaField->new( %properties )

Create a new metafield. %properties is a hash of the properties of the 
field, with the addition of "dataset", or if "dataset" is not set then
"confid" and "repository" must be provided instead.

Some field types require certain properties to be explicitly set. See
the main documentation.

=end InternalDoc

=cut
######################################################################

sub new
{
	my( $class, %properties ) = @_;

	# We'll inherit these from clone()
	delete $properties{".final"};
	delete $properties{"field_defaults"};

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
	my $realclass = "EPrints::MetaField::\u$properties{type}";
	if( $class ne $realclass )
	{
		if( !EPrints::Utils::require_if_exists( $realclass ) )
		{
			EPrints->abort( "couldn't parse $realclass: $@" );
		}
		return $realclass->new( %properties );
	}

	my $self = bless \%properties, $realclass;

	if( defined $properties{dataset} ) 
	{ 
		$self->{confid} = $properties{dataset}->{confid}; 
		$self->{repository} = $properties{dataset}->{repository};
	}

	if( !defined $self->{repository} )
	{
		EPrints->abort( "Tried to create a metafield without a dataset or an repository." );
	}

	my $repository = $self->{repository};

	if( defined &Scalar::Util::weaken )
	{
		Scalar::Util::weaken( $self->{dataset} );
		Scalar::Util::weaken( $self->{repository} );
	}

	my $field_defaults = $self->field_defaults;

	# warn of non-applicable parameters; handy for spotting
	# typos in the config file.
	foreach my $p_id (keys %$self)
	{
		next if $p_id eq "dataset";
		next if $p_id eq "repository";
		if( !exists $field_defaults->{$p_id} )
		{
# TODO / sf2 - DANGER - disabled that warning cos too many errors on bin/epadmin test
#
#			$self->{repository}->log( "Field '".$self->{dataset}->id.".".$self->{name}."' has invalid parameter:\n$p_id => $self->{$p_id}" );
		}
	}

	keys %{$field_defaults}; # Reset each position
	while(my( $p_id, $p_default ) = each %{$field_defaults})
	{
		next if defined $self->{$p_id};
		next if $p_default eq EP_PROPERTY_UNDEF;

		if( $p_default eq EP_PROPERTY_REQUIRED )
		{
			EPrints::abort( "Error in field property for ".$self->{dataset}->id.".".$self->{name}.": $p_id on a ".$self->{type}." metafield can't be undefined" );
		}
		elsif( $p_default ne EP_PROPERTY_NO_CHANGE )
		{
			$self->{$p_id} = $p_default;
		}
	}

	$self->{field_defaults} = $field_defaults;

	return $self;
}

=begin InternalDoc

=item $defaults = $field->field_defaults

Returns the default properties for this field as a hash reference.

=end InternalDoc

=cut

sub field_defaults
{
	my( $self ) = @_;

	my $repository = $self->{repository};

	my $field_defaults = $repository->get_field_defaults( $self->{type} );
	return $field_defaults if defined $field_defaults;

	$field_defaults = {$self->get_property_defaults};
	while(my( $p_id, $p_default ) = each %$field_defaults)
	{
		next if !defined $p_default;
		next if $p_default ne EP_PROPERTY_FROM_CONFIG;
		$p_default = $repository->config( "field_defaults" )->{ $p_id };
		$p_default = EP_PROPERTY_UNDEF if !defined $p_default;
		$field_defaults->{$p_id} = $p_default;
	}
	$repository->set_field_defaults( $self->{type}, $field_defaults );

	return $field_defaults;
}

######################################################################
=pod

=begin InternalDoc

=item $field->final

This method tells the metafield that it is now read only. Any call to
set_property will produce a abort error.

=end InternalDoc

=cut
######################################################################

sub final
{
	my( $self ) = @_;

	$self->{".final"} = 1;
}


######################################################################
=pod

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

	if( !exists $self->{field_defaults}->{$property} )
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

	if( $self->{field_defaults}->{$property} eq EP_PROPERTY_NO_CHANGE )
	{
		# don't set a default, just leave it alone
		return;
	}
	
	if( $self->{field_defaults}->{$property} eq EP_PROPERTY_REQUIRED )
	{
		EPrints::abort( "Error in field property for ".$self->{dataset}->id.".".$self->{name}.": $property on a ".$self->{type}." metafield can't be undefined" );
	}

	if( $self->{field_defaults}->{$property} eq EP_PROPERTY_UNDEF )
	{	
		$self->{$property} = undef;
		return;
	}

	$self->{$property} = $self->{field_defaults}->{$property};
}


######################################################################
=pod

=begin InternalDoc

=item $newfield = $field->clone

Clone the field, so the clone can be edited without affecting the
original. Does not deep copy properties which are references - these
should be set to new values, rather than the contents altered. Eg.
don't push to a cloned options list, replace it.

=end InternalDoc

=cut
######################################################################

sub clone
{
	my( $self ) = @_;

	return EPrints::MetaField->new( %{$self} );
}

=over 4

=item $repository = $field->repository

Return the L<EPrints::Repository> to which this field belongs.

=cut

sub repository
{
	my( $self ) = @_;
	return $self->{repository};
}

######################################################################
=pod

=item $dataset = $field->dataset

Return the L<EPrints::DataSet> to which this field belongs, or undef.

=cut
######################################################################

sub get_dataset { shift->dataset( @_ ) }
sub dataset
{
	my( $self ) = @_;
	return $self->{dataset};
}



######################################################################
=pod

=item $name = $field->name

Return the name of this field.

=cut
######################################################################

sub get_name { shift->name( @_ ) }
sub name
{
	my( $self ) = @_;
	return $self->{name};
}


######################################################################
=pod

=item $type = $field->type

Return the type of this field.

=cut
######################################################################

sub get_type { shift->type( @_ ) }
sub type
{
	my( $self ) = @_;
	return $self->{type};
}

sub has_property
{
	my( $self, $property ) = @_;

	return exists $self->{field_defaults}->{$property};
}

######################################################################
=pod

=item $value = $field->property( $property )

Return the value of the given property.

Special note about "required" property: It only indicates if the
field is always required. You must query the dataset to check if
it is required for a specific type.

=cut
######################################################################

sub get_property { shift->property( @_ ) }
sub property
{
	my( $self, $property ) = @_;

	if( !exists $self->{field_defaults}->{$property} )
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

=begin InternalDoc

=item $boolean = $field->is_type( @typenames )

Return true if the type of this field is one of @typenames.

=end InternalDoc

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

=item $out_list = $field->sort_values( $in_list, $langid )

Sorts the in_list into order, based on the "order values" of the 
values in the in_list. Assumes that the values are not a list of
multiple values. [ [], [], [] ], but rather a list of single values.

=cut
######################################################################

sub sort_values
{
	my( $self, $session, $in_list, $langid ) = @_;

	($in_list, $langid) = ($session, $in_list)
		if !UNIVERSAL::isa( $session, "EPrints::Repository" );

	my %ov;
	VALUE: for(@$in_list)
	{
		next if !defined $_;
		$ov{$_} = $self->ordervalue_single( $_, $self->{repository}, $langid );
	}

	my @out_list = sort { defined $a <=> defined $b || $ov{$a} cmp $ov{$b} } @$in_list;

	return \@out_list;
}


######################################################################
=pod

=begin InternalDoc

=item @values = $field->list_values( $value )

Return a list of every distinct value in this field. 

 - for simple fields: return ( $value )
 - for multiple fields: return @{$value}

This function is used by the item_matches method in Search.

=end InternalDoc

=cut
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
=pod

=begin InternalDoc

=item $value2 = $field->call_property( $property, @args )

Call the method described by $property. Pass it the arguments and
return the result.

The property may contain either a code reference, or the scalar name
of a method.

=end InternalDoc

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
=pod

=begin InternalDoc

=item $val = $field->value_from_sql_row( $session, $row )

Shift and return the value of this field from the database input $row.

=end InternalDoc

=cut
######################################################################

sub value_from_sql_row
{
	my( $self, $session, $row ) = @_;

	return shift @$row;
}

######################################################################
=pod

=begin InternalDoc

=item @row = $field->sql_row_from_value( $session, $value )

Return a list of values to insert into the database based on $value.

The values will normally be passed to L<DBI/bind_param>:

	$sth->bind_param( $idx, $row[0] )

If the value is an array ref it gets expanded:

	$sth->bind_param( $idx, @{$row[0]} )

This is necessary to support binding LOB data under various databases.

=end InternalDoc

=cut
######################################################################

sub sql_row_from_value
{
	my( $self, $session, $value ) = @_;

	return( $value );
}

######################################################################
=pod

=begin InternalDoc

=item %opts = $field->get_sql_properties( $session )

Map the relevant SQL properties for this field to options passed to L<EPrints::Database>::get_column_type().

=end InternalDoc

=cut
######################################################################

sub get_sql_properties
{
	my( $self, $session ) = @_;

	return (
		index => $self->{ "sql_index" },
		langid => $self->{ "sql_langid" },
		sorted => $self->{ "sql_sorted" },
	);
}

######################################################################
=pod

=begin InternalDoc

=item @types = $field->get_sql_type( $session )

Return the SQL column types of this field, used for creating tables.

=end InternalDoc

=cut
######################################################################

sub get_sql_type
{
	my( $self, $session ) = @_;

	my $database = $session->get_database;

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
=pod

=begin InternalDoc

=item $field = $field->create_ordervalues_field( $session [, $langid ] )

Return a new field object that this field can use to store order values, optionally for language $langid.

=end InternalDoc

=cut
######################################################################

sub create_ordervalues_field
{
	my( $self, $session, $langid ) = @_;

	return EPrints::MetaField->new(
		repository => $session,
		type => "longtext",
		name => $self->get_name,
		sql_sorted => 1,
		sql_langid => $langid,
	);
}

######################################################################
=pod

=begin InternalDoc

=item $sql = $field->get_sql_index

Return the columns that an index should be created over.

=end InternalDoc

=cut
######################################################################

sub get_sql_index
{
	my( $self ) = @_;
	
	return () unless( $self->get_property( "sql_index" ) );

	return $self->get_sql_names;
}




######################################################################
=pod

=begin InternalDoc

=item @sqlnames = $field->get_sql_names

Return the names of this field's columns as they appear in a SQL table.

=end InternalDoc

=cut
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
=pod

=begin InternalDoc

=item $boolean = $field->is_browsable

Return true if this field can be "browsed". ie. Used as a view.

=end InternalDoc

=cut
######################################################################

sub is_browsable
{
	return( 1 );
}


######################################################################
=pod

=item $values = $field->all_values( %opts )

Return a reference to an array of all the values of this field. 
For fields like "subject" or "set"
it returns all the variations. For fields like "text" return all 
the distinct values from the database.

Results are sorted according to the ordervalues of the current session.

=cut
######################################################################

sub all_values
{
	my( $self, %opts ) = @_;

	my $dataset = exists $opts{dataset} ? $opts{dataset} : $self->dataset;

	return $self->get_values( $self->repository, $dataset, %opts );
}
sub get_values
{
	my( $self, $session, $dataset, %opts ) = @_;

	my $langid = $opts{langid};
	$langid = $session->get_langid unless( defined $langid );

	my $unsorted_values = $self->get_unsorted_values( 
		$session,
		$dataset,	
		%opts );

	return $self->sort_values( $unsorted_values, $langid );
}

sub get_unsorted_values
{
	my( $self, $session, $dataset, %opts ) = @_;

	return $session->get_database->get_values( $self, $dataset );
}

sub get_ids_by_value
{
	my( $self, $session, $dataset, %opts ) = @_;

	return $session->get_database->get_ids_by_field_values( $self, $dataset, %opts );
}

######################################################################
=pod

=begin InternalDoc

=item $id = $field->get_id_from_value( $session, $value )

Returns a key based on $value that can be used in a view.

E.g. if "render_res" is "year" then the key of "2005-03-02" would be "2005".

Returns "NULL" if $value is undefined.

=end InternalDoc

=cut
######################################################################

sub get_id_from_value
{
	my( $self, $session, $value ) = @_;

	return defined($value) ? $value : "NULL";
}

######################################################################
=pod

=begin InternalDoc

=item $value = $field->get_value_from_id( $session, $id )

Returns the value from $id or undef if $id is "NULL".

=end InternalDoc

=cut
######################################################################

sub get_value_from_id
{
	my( $self, $session, $id ) = @_;

	return $id eq "NULL" ? undef : $id;
}

######################################################################
=pod

=begin InternalDoc

=item $ov = $field->ordervalue( $value, $session, $langid, $dataset )

Return a string representing this value which can be used to sort
it into order by comparing it alphabetically.

=end InternalDoc

=cut
######################################################################

sub ordervalue
{
	my( $self , $value , $session , $langid , $dataset ) = @_;

	return "" if( !EPrints::Utils::is_set( $value ) );

	if( defined $self->{make_value_orderkey} )
	{
		no strict "refs";
		return $self->call_property( "make_value_orderkey",
			$self, 
			$value, 
			$session, 
			$langid,
			$dataset );
	}

	if( !$self->get_property( "multiple" ) )
	{
		return $session->get_database->quote_ordervalue($self, $self->ordervalue_single( $value , $session , $langid, $dataset ));
	}

	my @r = ();	
	foreach( @$value )
	{
		push @r, $self->ordervalue_single( $_ , $session , $langid, $dataset );
	}
	return $session->get_database->quote_ordervalue($self, join( ":", @r ));
}


######################################################################
# 
# $ov = $field->ordervalue_single( $value, $session, $langid, $dataset )
# 
# undocumented
# 
######################################################################

sub ordervalue_single
{
	my( $self , $value , $session , $langid, $dataset ) = @_;

	return "" unless( EPrints::Utils::is_set( $value ) );

	if( defined $self->{make_single_value_orderkey} )
	{
		return $self->call_property( "make_single_value_orderkey",
			$self, 
			$value, 
			$dataset ); 
	}

	return $self->ordervalue_basic( $value, $session, $langid );
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
	my( $self, $value, $session, $langid ) = @_;

	return defined $value ? $value : "";
}

# XML output methods

sub to_xml
{
	my( $self, $value, %opts ) = @_;

	my $builder = EPrints::XML::SAX::Builder->new(
		repository => $self->{session}
	);
	$builder->start_document({});
	$builder->xml_decl({
		Version => '1.0',
		Encoding => 'utf-8',
	});
	$builder->start_prefix_mapping({
		Prefix => '',
		NamespaceURI => EPrints::Const::EP_NS_DATA,
	});
	$self->to_sax( $value, %opts, Handler => $builder );

	$builder->end_prefix_mapping({
		Prefix => '',
		NamespaceURI => EPrints::Const::EP_NS_DATA,
	});
	$builder->end_document({});

	return $builder->result()->documentElement;
}

sub to_sax
{
	my( $self, $value, %opts ) = @_;

	# MetaField::Compound relies on testing this specific attribute
	return if defined $self->{parent_name};

	return if !$opts{show_empty} && !EPrints::Utils::is_set( $value );

	my $handler = $opts{Handler};
	my $name = $self->name;

	$handler->start_element( {
		Prefix => '',
		LocalName => $name,
		Name => $name,
		NamespaceURI => EPrints::Const::EP_NS_DATA,
		Attributes => {},
	});

	if( ref($value) eq "ARRAY" )
	{
		foreach my $v (@$value)
		{
			$handler->start_element( {
				Prefix => '',
				LocalName => "item",
				Name => "item",
				NamespaceURI => EPrints::Const::EP_NS_DATA,
				Attributes => {},
			});
			$self->to_sax_basic( $v, %opts );
			$handler->end_element( {
				Prefix => '',
				LocalName => "item",
				Name => "item",
				NamespaceURI => EPrints::Const::EP_NS_DATA,
			});
		}
	}
	else
	{
		$self->to_sax_basic( $value, %opts );
	}

	$handler->end_element( {
		Prefix => '',
		LocalName => $name,
		Name => $name,
		NamespaceURI => EPrints::Const::EP_NS_DATA,
	});
}

sub to_sax_basic
{
	my( $self, $value, %opts ) = @_;

	$opts{Handler}->characters( { Data => $value } );
}

sub empty_value
{
	return "";
}

sub start_element
{
	my( $self, $data, $epdata, $state ) = @_;

	++$state->{depth};

	if( $state->{depth} == 1 )
	{
		$epdata->{$self->name} = $self->property( "multiple" ) ? [] : $self->empty_value;
		$state->{in_value} = !$self->property( "multiple" );
	}
	elsif(
		$state->{depth} == 2 &&
		$self->property( "multiple" )
	  )
	{
		if( $data->{LocalName} eq "item" )
		{
			push @{$epdata->{$self->name}}, $self->empty_value;
			$state->{in_value} = 1;
		}
		else
		{
			$state->{Handler}->message( "warning", $self->repository->xml->create_text_node( "Invalid XML element: $data->{LocalName}" ) )
				if defined $state->{Handler};
		}
	}
}

sub end_element
{
	my( $self, $data, $epdata, $state ) = @_;

	if( $state->{depth} == 1 || ($state->{depth} == 2 && $self->property( "multiple" )) )
	{
		$state->{in_value} = 0;
	}

	--$state->{depth};
}

sub characters
{
	my( $self, $data, $epdata, $state ) = @_;

	return if !$state->{in_value};

	my $value = $epdata->{$self->name};
	if( $state->{depth} == 2 ) # <foo><item>XXX
	{
		$value->[-1] .= $data->{Data};
	}
	elsif( $state->{depth} == 1 ) # <foo>XXX
	{
		$epdata->{$self->name} = $value . $data->{Data};
	}
}

sub render_xml_schema
{
	my( $self, $session ) = @_;

	my $name = $self->{sub_name} ? $self->{sub_name} : $self->{name};

	my $element = $session->make_element( "xs:element", name => $name );

	my $phraseid = $self->{dataset}->confid . "_fieldname_" . $self->get_name;
	my $helpid = $self->{dataset}->confid . "_fieldhelp_" . $self->get_name;
	if( $session->get_lang->has_phrase( $phraseid, $session ) )
	{
		my $annotation = $session->make_element( "xs:annotation" );
		$element->appendChild( $annotation );
		my $documentation = $session->make_element( "xs:documentation" );
		$annotation->appendChild( $documentation );
		$documentation->appendChild( $session->make_text( "\n" ) );
		$documentation->appendChild( $session->make_text( $session->phrase( $phraseid ) ) );
		if( $session->get_lang->has_phrase( $helpid, $session ) )
		{
			$documentation->appendChild( $session->make_text( "\n\n" ) );
			$documentation->appendChild( $session->make_text( $session->phrase( $helpid ) ) );
		}
		$documentation->appendChild( $session->make_text( "\n" ) );
	}

	if( $self->get_property( "multiple" ) )
	{
		my $complexType = $session->make_element( "xs:complexType" );
		$element->appendChild( $complexType );
		my $sequence = $session->make_element( "xs:sequence" );
		$complexType->appendChild( $sequence );
		my $item = $session->make_element( "xs:element", name => "item", type => $self->get_xml_schema_type(), minOccurs => "0", maxOccurs => "unbounded" );
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

sub get_xml_schema_type { 'xs:string' }

# any sub-class that provides field-specific restrictions will need this
sub get_xml_schema_field_type
{
	my( $self ) = @_;

	return join '.', $self->{type}, $self->{dataset}->base_id, $self->{name};
}

sub from_search_form
{
	my( $self, $session, $basename ) = @_;

	my( $value, $match, $merge ) =
	(
		scalar($session->param( $basename )),
		scalar($session->param( $basename."_match" )),
		scalar($session->param( $basename."_merge" )),
	);

	if( ($match && $match eq "EX") || $self->property( "match" ) eq "EX" )
	{
		$merge = "ANY";
	}

	return( $value, $match, $merge );
}		

sub get_search_group { return 'basic'; } 

# return system defaults for this field type
sub get_property_defaults
{
	return (
		provenance => EP_PROPERTY_FROM_CONFIG,
		replace_core => EP_PROPERTY_FALSE,
		allow_null 	=> EP_PROPERTY_TRUE,
		can_clone 	=> EP_PROPERTY_TRUE,
		confid 		=> EP_PROPERTY_NO_CHANGE,
		export_as_xml 	=> EP_PROPERTY_TRUE,		# TODO/sf2 - internal format?..
		export 		=> EP_PROPERTY_TRUE,		# TODO/sf2 - for other exporters?..
		import		=> EP_PROPERTY_TRUE,
		make_single_value_orderkey 	=> EP_PROPERTY_UNDEF,
		make_value_orderkey 		=> EP_PROPERTY_UNDEF,
		show_in_fieldlist	=> EP_PROPERTY_TRUE,
		maxlength 	=> $EPrints::MetaField::VARCHAR_SIZE,
		multiple 	=> EP_PROPERTY_FALSE,
		name 		=> EP_PROPERTY_REQUIRED,
		required 	=> EP_PROPERTY_FALSE,
		requiredlangs 	=> [],
		sql_index 	=> EP_PROPERTY_TRUE,
		sql_langid 	=> EP_PROPERTY_UNDEF,
		sql_sorted	=> EP_PROPERTY_FALSE,
		text_index 	=> EP_PROPERTY_FALSE,
		type 		=> EP_PROPERTY_REQUIRED,
		sub_name	=> EP_PROPERTY_UNDEF,
		parent_name	=> EP_PROPERTY_UNDEF,
		parent		=> EP_PROPERTY_UNDEF,
		volatile	=> EP_PROPERTY_FALSE,
		virtual		=> EP_PROPERTY_FALSE,
		default_value => EP_PROPERTY_UNDEF,
		match       => "EQ",
		merge       => "ALL",

		join_path	=> EP_PROPERTY_UNDEF,

		indexes => EP_PROPERTY_UNDEF,
);
}

=begin InternalDoc

=item $value = $field->get_default_value( $session )

Return the default value for this field. This is only applicable to very simple
cases such as timestamps, auto-incremented values etc.

Any complex initialisation should be done in the "set_eprint_automatic_fields"
callback (or the equivalent for the given object).

=end InternalDoc

=cut

sub get_default_value
{
	my( $self, $session ) = @_;

	return $self->get_property( "default_value" );
}

=begin InternalDoc

=item ( $terms, $grep_terms, $ignored ) = $field->get_index_codes( $session, $value )

Get indexable terms from $value. $terms is a reference to an array of strings to index. $grep_terms is a reference to an array of terms to add to the grep index. $ignored is a reference to an array of terms that should be ignored (e.g. stop words in a free-text field).

=end InternalDoc

=cut

sub get_index_codes
{
	my( $self, $session, $value ) = @_;

	return( [], [], [] ) unless( EPrints::Utils::is_set( $value ) );

	if( !$self->get_property( "multiple" ) )
	{
		return $self->get_index_codes_basic( $session, $value );
	}
	my( $codes, $grepcodes, $ignored ) = ( [], [], [] );
	foreach my $v (@{$value} )
	{		
		my( $c,$g,$i ) = $self->get_index_codes_basic( $session, $v );
		push @{$codes},@{$c};
		push @{$grepcodes},@{$g};
		push @{$ignored},@{$i};
	}

	return( $codes, $grepcodes, $ignored );
}

sub get_index_codes_basic
{
	my( $self, $session, $value ) = @_;

	return( [], [], [] );
}

=begin InternalDoc

=item @terms = $field->split_search_value( $session, $value )

Split $value into terms that can be used to search against this field.

=end InternalDoc

=cut

sub split_search_value
{
	my( $self, $session, $value ) = @_;

#	return EPrints::Index::split_words( 
#			$session,
#			EPrints::Index::apply_mapping( $session, $value ) );

	return split /\s+/, $value;
}

=begin InternalDoc

=item $cond = $field->get_search_conditions( $session, $dataset, $value, $match, $merge, $mode )

Return a L<Search::Condition> for $value based on this field.

=end InternalDoc

=cut

sub get_search_conditions
{
	my( $self, $session, $dataset, $search_value, $match, $merge,
		$search_mode ) = @_;

	if( $match eq "SET" )
	{
		return EPrints::Search::Condition->new(
				"is_not_null",
				$dataset,
				$self );
	}

	if( $match eq "EX" )
	{
		if( !EPrints::Utils::is_set( $search_value ) )
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
			$session, 
			$dataset, 
			$search_value, 
			$match, 
			$merge, 
			$search_mode );
}

=begin InternalDoc

=item $cond = $field->get_search_conditions_not_ex( $session, $dataset, $value, $match, $merge, $mode )

Return the search condition for a search which is not-exact ($match ne "EX").

=end InternalDoc

=cut

sub get_search_conditions_not_ex
{
       my( $self, $session, $dataset, $search_value, $match, $merge,
               $search_mode ) = @_;
       
       if( $match eq "EQ" )
       {
               return EPrints::Search::Condition->new( 
                       '=', 
                       $dataset,
                       $self, 
                       $search_value );
       }

       return EPrints::Search::Condition->new( 
                       'index',
                       $dataset,
                       $self, 
                       $search_value );
}

sub get_value { &value }
sub value
{
	my( $self, $object ) = @_;

	return $object->get_value_raw( $self->{name} );
}

# returns 0/1 on failure/success
sub set_value
{
	my( $self, $dataobj, $value ) = @_;

	# sf2 - doing a separate validation test for whether the field is multiple (and we got an array) is done separately - this way, it's only
	#	called once - compound fields could otherwise do the "is-multiple test" several times

	return 0 if( !$self->validate_multiple( $value ) || !$self->validate_value( $value ) );
	
# TODO/sf2 - what to do if $valid_value is undef (in the sense that no valid values were found):
# - should we carry on the set_value_raw - in which case the former data will be overwritten to be NULL
# - if not, how do we detect that no values were validated?
# - should validate_value returns the number of valid values it found?? "undef" is valid btw

	return $dataobj->set_value_raw( $self->name, $value );
}

sub validate_multiple
{
	my( $self, $value ) = @_;

	# sf2 - don't validate if we're expecting an array
	if( defined $value && $self->property( 'multiple' ) && ref( $value ) ne 'ARRAY' )
	{
		$self->repository->log( "Non-array reference passed to multiple field: ".$self->dataset->id."/".$self->name );
		return 0
	}

	return 1;	
}

# assumes a SCALAR
sub validate_type
{
        my( $self, $value ) = @_;

        return 1 if( !defined $value || ref( $value ) eq '' );

        $self->repository->log( "Non-scalar value passed to field: ".$self->dataset->id."/".$self->name );

        return 0;
}

# assumes everything is OK in the ISA class
sub validate_value
{
	my( $self, $value ) = @_;

	return 1;
}

# returns potential sub_fields - see Compound, Multipart
sub sub_fields
{
	return [];
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


=begin InternalDoc

=item @problems = $field->validate( $session, $value, $dataobj )

Returns an array of DOM problems with $value for this field.

=end InternalDoc

=cut

sub validate
{
	my( $self, $session, $value, $object ) = @_;

	my @problems = $session->call(
		"validate_field",
		$self,
		$value,
		$session );

	$self->{repository}->run_trigger( EPrints::Const::EP_TRIGGER_VALIDATE_FIELD(),
		field => $self,
		dataobj => $object,
		value => $value,
		problems => \@problems,
	);

	return @problems;
}

sub basename 
{
  my ( $self, $prefix ) = @_;

  my $basename;

  if( defined $prefix )
    {
      $basename = $prefix."_".$self->{name};
    }
  else
    {
      $basename = $self->{name};
    }

  return $basename;
}


######################################################################

1;

=pod

=back

=cut


=head1 COPYRIGHT

=for COPYRIGHT BEGIN

Copyright 2000-2011 University of Southampton.

=for COPYRIGHT END

=for LICENSE BEGIN

This file is part of EPrints L<http://www.eprints.org/>.

EPrints is free software: you can redistribute it and/or modify it
under the terms of the GNU Lesser General Public License as published
by the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

EPrints is distributed in the hope that it will be useful, but WITHOUT
ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser General Public
License for more details.

You should have received a copy of the GNU Lesser General Public
License along with EPrints.  If not, see L<http://www.gnu.org/licenses/>.

=for LICENSE END

