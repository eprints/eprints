######################################################################
#
# EPrints::MetaField::Itemref;
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

	$properties{fields} = [] if !defined $properties{fields};

	push @{$properties{fields}}, {
			sub_name=>"title",
			type=>"text",
		}, {
			sub_name=>"id",
			type=>"int",
			input_cols=>6,
		};

	my $self = $class->SUPER::new( %properties );

	return $self;
}

sub get_property_defaults
{
	my( $self ) = @_;
	my %defaults = $self->SUPER::get_property_defaults;
	$defaults{datasetid} = $EPrints::MetaField::REQUIRED;
	$defaults{text_index} = 0;
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

	my $dataobj;
	if( EPrints::Utils::is_set( $value->{id} ) )
	{
		my $ds = $session->dataset( $self->get_property('datasetid') );
		$dataobj = $ds->dataobj( $value->{id} );

		if( !defined $dataobj )
		{
			return $session->html_phrase( "lib/metafield/itemref:not_found",
				id=>$xml->create_text_node( $value->{id} ),
				objtype=>$session->html_phrase( "datasetname_".$ds->base_id));
		}
	}
	else
	{
		return $xml->create_text_node( $value->{title} );
	}

	if( EPrints::Utils::is_set( $value->{title} ) )
	{
		my $link = $xml->create_element( "a", href => $dataobj->get_url );
		$link->appendChild( $xml->create_text_node( $value->{title} ) );

		return $link;
	}
	else
	{
		return $dataobj->render_citation_link;
	}
}

sub _dataset
{
	my( $self ) = @_;

	return $self->{repository}->dataset( $self->get_property('datasetid') );
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

	my $dataset = $self->_dataset;
	my $priv = $dataset->id . "/view";
	if(
		!$self->get_property( "sub_name" ) &&
		$session->current_user->allow( $priv )
	  )
	{
		my $url = $session->current_url( path => "cgi", "users/home" );
		$url .= "?screen=Listing&dataset=".$dataset->id;
		$f->appendChild(
			$session->render_link( $url, target => "_new" )
		)->appendChild(
			$session->html_phrase( "Plugin/Screen/Listing:page_title",
				dataset => $dataset->render_name( $session )
			)
		);
	}

	$f->appendChild( $self->SUPER::render_input_field_actual( @_[1..$#_] ) );

	return $f;
}

######################################################################
1;
