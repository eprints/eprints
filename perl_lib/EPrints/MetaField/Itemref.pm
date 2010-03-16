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

use EPrints::MetaField::Int;
@ISA = qw( EPrints::MetaField::Int );

use strict;

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

	my $desc = $self->render_single_value( $session, $value );

	push @{$ex->[0]}, {el=>$desc, style=>"padding: 0 0.5em 0 0.5em;"};

	return $ex;
}

sub render_single_value
{
	my( $self, $session, $value ) = @_;

	if( !defined $value )
	{
		return $session->make_doc_fragment;
	}

	my $object = $self->get_item( $session, $value );

	if( defined $object )
	{
		return $object->render_citation_link;
	}

	my $ds = $session->dataset( $self->get_property('datasetid') );

	return $session->html_phrase( 
		"lib/metafield/itemref:not_found",
			id=>$session->make_text($value),
			objtype=>$session->html_phrase( "datasetname_".$ds->base_id));
}

sub get_item
{
	my( $self, $session, $value ) = @_;

	my $ds = $session->dataset( $self->get_property('datasetid') );

	return $ds->dataobj( $value );
}


sub get_input_elements
{   
	my( $self, $session, $value, $staff, $obj, $basename ) = @_;

	my $input = $self->SUPER::get_input_elements( $session, $value, $staff, $obj, $basename );

	my $buttons = $session->make_doc_fragment;
	$buttons->appendChild( 
		$session->render_internal_buttons( 
			$self->{name}."_null" => $session->phrase(
				"lib/metafield/itemref:lookup" )));

	push @{ $input->[0] }, {el=>$buttons};

	return $input;
}




######################################################################
1;
