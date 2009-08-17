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

package EPrints::MetaField::Itemref;

use strict;
use warnings;

BEGIN
{
	our( @ISA );

	@ISA = qw( EPrints::MetaField::Int );
}

use EPrints::MetaField::Int;

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
	my( $self, $handle, $value, $basename, $staff ) = @_;

	my $ex = $self->SUPER::get_basic_input_elements( $handle, $value, $basename, $staff );

	my $desc = $self->render_single_value( $handle, $value );

	push @{$ex->[0]}, {el=>$desc, style=>"padding: 0 0.5em 0 0.5em;"};

	return $ex;
}

sub render_single_value
{
	my( $self, $handle, $value ) = @_;

	if( !defined $value )
	{
		return $handle->make_doc_fragment;
	}

	my $object = $self->get_item( $handle, $value );

	if( defined $object )
	{
		return $object->render_citation_link;
	}

	my $ds = $handle->get_repository->get_dataset( 
			$self->get_property('datasetid') );

	return $handle->html_phrase( 
		"lib/metafield/itemref:not_found",
			id=>$handle->make_text($value),
			objtype=>$handle->html_phrase(
		"general:dataset_object_".$ds->confid));
}

sub get_item
{
	my( $self, $handle, $value ) = @_;

	my $ds = $handle->get_repository->get_dataset( 
			$self->get_property('datasetid') );

	return $ds->get_object( $handle, $value );
}


sub get_input_elements
{   
	my( $self, $handle, $value, $staff, $obj, $basename ) = @_;

	my $input = $self->SUPER::get_input_elements( $handle, $value, $staff, $obj, $basename );

	my $buttons = $handle->make_doc_fragment;
	$buttons->appendChild( 
		$handle->render_internal_buttons( 
			$self->{name}."_null" => $handle->phrase(
				"lib/metafield/itemref:lookup" )));

	push @{ $input->[0] }, {el=>$buttons};

	return $input;
}




######################################################################
1;
