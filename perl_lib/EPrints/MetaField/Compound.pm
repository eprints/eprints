######################################################################
#
# EPrints::MetaField::Compound;
#
######################################################################
#
#
######################################################################

=pod

=head1 NAME

B<EPrints::MetaField::Compound> - Magic type of field which actually 
combines several other fields into a data structure.

=head1 DESCRIPTION

not done

=over 4

=cut

package EPrints::MetaField::Compound;

use EPrints::MetaField;
@ISA = qw( EPrints::MetaField );

use strict;

sub new
{
	my( $class, %properties ) = @_;

	$properties{fields_cache} = [];

	my $self = $class->SUPER::new( %properties );

	my %seen;
	foreach my $inner_field ( @{$properties{fields}}, $self->extra_subfields )
	{
		# use 'name' for sub-fields as you'd do for normal fields
		$inner_field->{sub_name} ||= delete $inner_field->{name};

		if( !EPrints::Utils::is_set( $inner_field->{sub_name} ) )
		{
			EPrints->abort( "Sub fields of ".$self->dataset->id.".".$self->name." need the sub_name property to be set." );
		}
		if( $seen{$inner_field->{sub_name}}++ )
		{
			EPrints->abort( $self->dataset->id.".".$self->name." already contains a sub-field called '$inner_field->{sub_name}'" );
		}
		my $field = EPrints::MetaField->new( 
		# these properties can be overriden
			export_as_xml => $properties{ "export_as_xml" },
			import => $properties{ "import" },
		# inner field's properties
			%{$inner_field},
			name => join('_', $self->name, $inner_field->{sub_name}),
		# these properties must be the same as the compound
			parent => $self,
			parent_name => $self->get_name(),
			dataset => $self->get_dataset(), 
			provenance => $self->property( "provenance" ),
			multiple => $properties{ "multiple" },
			volatile => $properties{ "volatile" },
			virtual => 1,
		);

		# avoid circular references if we can
		Scalar::Util::weaken( $field->{parent} )
			if defined &Scalar::Util::weaken;
		push @{$self->{fields_cache}}, $field;
	}

	return $self;
}

=item @epdata = $field->extra_subfields()

Returns a list of sub-field definitions that will be added to this compound field.

This method should be overridden by sub-classes.

=cut

sub extra_subfields
{
	my( $self ) = @_;

	return ();
}

sub to_sax_basic
{
	my( $self, $value, %opts ) = @_;

	return if !EPrints::Utils::is_set( $value );

	foreach my $field (@{$self->{fields_cache}})
	{
		next if !$field->property( "export_as_xml" );

		my $alias = $field->property( "sub_name" );
		my $v = $value->{$alias};
		# cause the sub-field to behave like it's a normal field
		local $field->{multiple} = 0;
		local $field->{parent_name};
		local $field->{name} = $field->{sub_name};
		$field->to_sax( $v, %opts );
	}
}

sub empty_value
{
	return {};
}

sub start_element
{
	my( $self, $data, $epdata, $state ) = @_;

	++$state->{depth};

	# if we're inside a sub-field just call it
	if( defined(my $field = $state->{handler}) )
	{
		$field->start_element( $data, $epdata, $state->{$field} );
	}
	# or initialise all fields at <creators>
	elsif( $state->{depth} == 1 )
	{
		foreach my $field (@{$self->property( "fields_cache" )})
		{
			local $data->{LocalName} = $field->property( "sub_name" );
			$state->{$field} = {%$state,
				depth => 0,
			};
			$field->start_element( $data, $epdata, $state->{$field} );
		}
	}
	# add a new empty value for each sub-field at <item>
	elsif( $state->{depth} == 2 && $self->property( "multiple" ) )
	{
		foreach my $field (@{$self->property( "fields_cache" )})
		{
			$field->start_element( $data, $epdata, $state->{$field} );
		}
	}
	# otherwise we must be starting a new sub-field value
	else
	{
		foreach my $field (@{$self->property( "fields_cache" )})
		{
			if( $field->property( "sub_name" ) eq $data->{LocalName} )
			{
				$state->{handler} = $field;
				last;
			}
		}
	}
}

sub end_element
{
	my( $self, $data, $epdata, $state ) = @_;

	# finish all fields
	if( $state->{depth} == 1 )
	{
		my $value = $epdata->{$self->name} = $self->property( "multiple" ) ? [] : $self->empty_value;

		foreach my $field (@{$self->property( "fields_cache" )})
		{
			local $data->{LocalName} = $field->property( "sub_name" );
			$field->end_element( $data, $epdata, $state->{$field} );

			my $v = delete $epdata->{$field->name};
			if( ref($value) eq "ARRAY" )
			{
				foreach my $i (0..$#$v)
				{
					$value->[$i]->{$field->property( "sub_name" )} = $v->[$i];
				}
			}
			else
			{
				$value->{$field->property( "sub_name" )} = $v;
			}

			delete $state->{$field};
		}
	}
	# end a new <item> for every field
	elsif( $state->{depth} == 2 && $self->property( "multiple" ) )
	{
		foreach my $field (@{$self->property( "fields_cache" )})
		{
			$field->end_element( $data, $epdata, $state->{$field} );
		}
	}
	# end of a sub-field's content
	elsif( $state->{depth} == 2 || ($state->{depth} == 3 && $self->property( "multiple" )) )
	{
		delete $state->{handler};
	}
	# otherwise call the sub-field
	elsif( defined(my $field = $state->{handler}) )
	{
		$field->end_element( $data, $epdata, $state->{$field} );
	}

	--$state->{depth};
}

sub characters
{
	my( $self, $data, $epdata, $state ) = @_;

	if( defined(my $field = $state->{handler}) )
	{
		$field->characters( $data, $epdata, $state->{$field} );
	}
}

# This type of field is virtual.
sub is_virtual
{
	my( $self ) = @_;

# TODO/sf2 - calling for danger :-)
# this allows Compound to be stored in a single table: [ counterid | pos | @sub_fields ] 
	return 0;
#	return 1;
}

# from Metafield/Multipart
sub get_sql_names
{
        my( $self ) = @_;

        return map { $_->get_sql_names } @{$self->{fields_cache}};
}


sub get_sql_type
{
	my( $self, $session ) = @_;

# from MetaField/Multipart
	return map { $_->get_sql_type( $session ) } @{$self->{fields_cache}};
#	return undef;
}

sub sql_row_from_value
{
        my( $self, $session, $value ) = @_;

        my @row;

        for(@{$self->{fields_cache}})
        {
                push @row,
                        $_->sql_row_from_value( $session, $value->{$_->property( "sub_name" )} );
        }

        return @row;
}

sub value_from_sql_row
{
        my( $self, $session, $row ) = @_;

        my %value;

        for(@{$self->{fields_cache}})
        {
                $value{$_->property( "sub_name" )} =
                        $_->value_from_sql_row( $session, $row );
        }

        return \%value;
}


#end from Multipart





# UNUSED
sub get_alias_to_fieldname
{
	my( $self ) = @_;

	my %addr = ();

	my $f = $self->get_property( "fields_cache" );
	foreach my $sub_field ( @{$f} )
	{
		$addr{$sub_field->{sub_name}} = $sub_field->{name};
	}

	return %addr;
}

# UNUSED
sub get_fieldname_to_alias
{
	my( $self ) = @_;

	return reverse $self->get_alias_to_fieldname;
}


sub validate_value
{
	my( $self, $value ) = @_;

	return 1 if( !defined $value );
	return 0 if( !$self->SUPER::validate_value( $value ) );

	my $is_array = ref( $value ) eq 'ARRAY';

	foreach my $single_value ( $is_array ?
        	        @$value :
                	$value
        )
        {
		if( !$self->validate_type( $single_value ) )
		{
			return 0;
		}

		foreach my $sub_field ( @{$self->sub_fields} )
		{
			# sub-field validation
			return 0 if( !$sub_field->validate_value( $single_value->{$sub_field->property( 'sub_name' )} ) );
		}
	}

	return 1;
}

sub sub_fields
{
	$_[0]->{fields_cache};
}

sub validate_type
{
	my( $self, $value ) = @_;

	return 1 if( !defined $value || ref( $value ) eq 'HASH' );

	$self->repository->log( "Non-hash value '$value' passed to field ".$self->dataset->id."/".$self->name );
	
	return 0;
}

# merge sub-fields values with its parents' values
# if you do dataobj->set_value( 'creators_name', @names ) and the parent is creators = { name => .., id => .. };
# this will merge @names with the current creators_name values
sub merge_values
{
	my( $self, $dataobj, $subfieldname, $values ) = @_;

	my $name = $self->name;
	$subfieldname =~ s/$name\_//;

	$values = [$values] if( ref( $values ) ne 'ARRAY' );
	
	my $current_values = EPrints::Utils::clone( $dataobj->value( $self->name ) );
	$current_values = [ $current_values ] if( !$self->property( 'multiple' ) );

	my $max_array = scalar( @$values ) > scalar( @$current_values ) ? scalar( @$values ) : scalar( @$current_values );
	
	for( my $i=0; $i < $max_array; $i++ )
	{
		my $row = $current_values->[$i] ||= {};
		$row->{$subfieldname} = $values->[$i] if( $values->[$i] );
	}

	return $dataobj->set_value_raw( $self->name, $current_values );
}

sub set_value
{
	my( $self, $object, $value ) = @_;


return $self->SUPER::set_value( $object, $value );

	if( $self->get_property( "multiple" ) )
	{
		foreach my $field (@{$self->{fields_cache}})
		{
			my $alias = $field->property( "sub_name" );
			$field->set_value( $object, [
				map { $_->{$alias} } @$value
			] );
		}
	}
	else
	{
		foreach my $field (@{$self->{fields_cache}})
		{
			my $alias = $field->property( "sub_name" );
			$field->set_value( $object, $value->{$alias} );
		}
	}
}

sub validate
{
	my( $self, $session, $value, $object ) = @_;

	my $f = $self->get_property( "fields_cache" );
	my @problems;
	foreach my $field_conf ( @{$f} )
	{
		push @problems, $object->validate_field( $field_conf->{name} );
	}
	return @problems;
}

# don't index
sub get_index_codes
{
	my( $self, $session, $value ) = @_;

	return( [], [], [] );
}

sub get_property_defaults
{
	my( $self ) = @_;
	my %defaults = $self->SUPER::get_property_defaults;
	$defaults{fields} = $EPrints::MetaField::REQUIRED;
	$defaults{fields_cache} = $EPrints::MetaField::REQUIRED;
	$defaults{show_in_fieldlist} = 0;
	$defaults{export_as_xml} = 1;
	$defaults{text_index} = 0;
	return %defaults;
}

sub get_xml_schema_type
{
	my( $self ) = @_;

	return $self->get_xml_schema_field_type;
}

sub get_search_conditions
{
	my( $self, $session, $dataset, $search_value, $match, $merge,
		$search_mode ) = @_;

	if( $match eq "EX" )
	{
		if( ref($search_value) ne "HASH" )
		{
			$search_value = $self->get_value_from_id( $session, $search_value );
		}
		return EPrints::Search::Condition->new(
			'=',
			$dataset,
			$self,
			$search_value
		);
	}

	return shift->get_search_conditions_not_ex( @_ );
}

sub get_search_conditions_not_ex
{
	my( $self, $session, $dataset, $search_value, $match, $merge,
		$search_mode ) = @_;

	EPrints::abort( "Unsupported attempt to search compound field on ".$session->get_id . "." . $self->{dataset}->confid . "." . $self->get_name );
}

# don't know how to turn a compound into a order value
sub ordervalue_single
{
	my( $self, $value, $session, $langid, $dataset ) = @_;

	return "";
}

sub get_value_from_id
{
	my( $self, $session, $id ) = @_;

	return {} if $id eq "NULL";

	my $value = {};

	my @parts = 
		map { URI::Escape::uri_unescape($_) }
		split /:/, $id, scalar(@{$self->property( "fields_cache" )});

	foreach my $field (@{$self->property( "fields_cache" )})
	{
		my $v = $field->get_value_from_id( $session, shift @parts );
		$value->{$field->property( "sub_name" )} = $v;
	}

	return $value;
}

sub get_id_from_value
{
	my( $self, $session, $value ) = @_;

	return "NULL" if !defined $value;

	my @parts;
	foreach my $field (@{$self->property( "fields_cache" )})
	{
		push @parts, $field->get_id_from_value(
			$session,
			$value->{$field->property( "sub_name" )}
		);
	}

	return join(":",
		map { URI::Escape::uri_escape($_, ":%") }
		@parts);
}

######################################################################

######################################################################
1;

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

