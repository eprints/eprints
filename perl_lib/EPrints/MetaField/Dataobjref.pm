######################################################################
#
# EPrints::MetaField::Itemref;
#
######################################################################
#
#
######################################################################

=pod

=head1 NAME

B<EPrints::MetaField::Itemref> - Reference to an object with an "int" type of ID field.

=head1 DESCRIPTION

not done

=over 4

=cut

package EPrints::MetaField::Dataobjref;

use EPrints::MetaField::Compound;
@ISA = qw( EPrints::MetaField::Compound );

use strict;

sub new
{
	my( $class, %properties ) = @_;

	$properties{input_lookup_url} = 'lookup/dataobjref' if !defined $properties{input_lookup_url};

	my $self = $class->SUPER::new( %properties );

	return $self;
}

sub extra_subfields
{
	my( $self ) = @_;

	return (
		{ sub_name=>"id", type=>"int", input_cols=>6, },
	);
}

sub get_property_defaults
{
	my( $self ) = @_;
	my %defaults = $self->SUPER::get_property_defaults;
	$defaults{datasetid} = $EPrints::MetaField::REQUIRED;
	$defaults{match} = "IN";
	$defaults{text_index} = 1;
	return %defaults;
}

sub get_basic_input_elements
{
	my( $self, $session, $value, $basename, $staff ) = @_;

	my $ex = $self->SUPER::get_basic_input_elements( $session, $value, $basename, $staff );

#	my $desc = $self->render_single_value( $session, $value );

#	push @{$ex->[0]}, {el=>$desc, style=>"padding: 0 0.5em 0 0.5em;"};

	return $ex;
}

sub render_value
{
	shift->EPrints::MetaField::render_value( @_ );
}

sub render_value_actual
{
	shift->EPrints::MetaField::render_value_actual( @_ );
}

sub render_value_no_multiple
{
	my( $self, $session, $value, $alllangs, $nolink, $object ) = @_;

	my $xml = $session->xml;

	if( !EPrints::Utils::is_set( $value ) )
	{
		return $xml->create_document_fragment;
	}

	my $ds = $session->dataset( $self->get_property('datasetid') );

	my $frag = $xml->create_document_fragment;
	my $extras = $xml->create_document_fragment;

	# populate extras with values that aren't part of the referenced dataobj
	foreach my $field (@{$self->property( "fields_cache" )})
	{
		my $name = $field->property( "sub_name" );
		next if $name eq "id";
		next if $ds->has_field( $name );
		next if !EPrints::Utils::is_set( $value->{$name} );
		$extras->appendChild( $xml->create_text_node( ", " ) ) if $extras->hasChildNodes;
		$extras->appendChild( $field->render_single_value( $session, $value->{$name}, $alllangs, $nolink, $object ) );
	}

	# retrieve the remote dataobj (or fake it with the data we have)
	my $dataobj;
	if( EPrints::Utils::is_set( $value->{id} ) )
	{
		$dataobj = $ds->dataobj( $value->{id} );

		if( defined $dataobj )
		{
			$frag->appendChild( $dataobj->render_citation_link() );
		}
		else
		{
			$frag->appendChild( $session->html_phrase( "lib/metafield/itemref:not_found",
				id=>$xml->create_text_node( $value->{id} ),
				objtype=>$session->html_phrase( "datasetname_".$ds->base_id))
			);
		}
	}
	else
	{
		my $dataobj = $ds->make_dataobj({});
		foreach my $name (keys %$value)
		{
			next if $name eq "id";
			next if !$ds->has_field( $name );
			$dataobj->set_value( $name, $value->{$name} );
		}

		$frag->appendChild( $dataobj->render_citation() );
	}

	if( $extras->hasChildNodes )
	{
		$frag->appendChild( $xml->create_text_node( " (" ) );
		$frag->appendChild( $extras );
		$frag->appendChild( $xml->create_text_node( ")" ) );
	}

	return $frag;
}

sub _dataset
{
	my( $self ) = @_;

	return $self->{repository}->dataset( $self->get_property('datasetid') );
}

sub get_item
{
	my ($self, $session, $value) = @_;

	return $self->dataobj($value);
}

sub dataobj
{
	my( $self, $value ) = @_;

	return undef if !defined $value;

	return $self->_dataset->dataobj( $value->{id} );
}

sub get_input_elements
{   
	my( $self, $session, $value, $staff, $obj, $basename ) = @_;

	my $input = $self->SUPER::get_input_elements( $session, $value, $staff, $obj, $basename );

#	my $buttons = $session->make_doc_fragment;
#	$buttons->appendChild( 
#		$session->render_internal_buttons( 
#			$self->{name}."_null" => $session->phrase(
#				"lib/metafield/itemref:lookup" )));
#
#	push @{ $input->[0] }, {el=>$buttons};

	return $input;
}

sub render_input_field_actual
{
	my( $self, $session, $value, $dataset, $staff, $hidden_fields, $obj, $basename ) = @_;

	my $f = $session->make_doc_fragment;

	my $_dataset = $self->_dataset;
	my $priv = $_dataset->id . "/view";
	if(
		!$self->get_property( "sub_name" ) &&
		$session->current_user->allow( $priv )
	  )
	{
		my $url = $session->current_url( path => "cgi", "users/home" );
		$url .= "?screen=Listing&dataset=".$_dataset->id;
		$f->appendChild(
			$session->render_link( $url, target => "_new" )
		)->appendChild(
			$session->html_phrase( "Plugin/Screen/Listing:page_title",
				dataset => $_dataset->render_name( $session )
			)
		);
	}

	$f->appendChild( $self->SUPER::render_input_field_actual( @_[1..$#_] ) );

	return $f;
}

sub get_search_conditions
{
	return shift->EPrints::MetaField::Subobject::get_search_conditions(@_);
}

# Compound ignores get_index_codes()
sub get_index_codes
{
	return shift->EPrints::MetaField::get_index_codes(@_);
}

sub get_index_codes_basic
{
	my( $self, $session, $value ) = @_;

	my @codes;

	my $dataobj = $self->dataobj($value);

	if (defined $dataobj)
	{
		my $dataset = $dataobj->{dataset};
		foreach my $field ($dataset->fields)
		{
			my ($codes) = $field->get_index_codes(
				$session,
				$field->get_value($dataobj)
			);
			push @codes, @$codes;
		}
	}
	else
	{
		foreach my $field (@{$self->property('fields_cache')})
		{
			my ($codes) = $field->get_index_codes_basic(
				$session,
				$value->{$field->property('sub_name')}
			);
			push @codes, @$codes;
		}
	}

	return( \@codes, [], [] );
}

######################################################################
1;

=head1 COPYRIGHT

=for COPYRIGHT BEGIN

Copyright 2000-2013 University of Southampton.

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

