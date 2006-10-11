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
	my( $self, $session, $value, $basename, $staff ) = @_;

	my $ex = $self->SUPER::get_basic_input_elements( $session, $value, $basename, $staff );

	my $desc = $self->render_single_value( $session, $value );

	push @{$ex->[0]}, {el=>$desc};

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

	my $ds = $session->get_repository->get_dataset( 
			$self->get_property('datasetid') );

	return $session->html_phrase( 
		"lib/metafield/itemref:not_found",
			id=>$session->make_text($value),
			objtype=>$session->html_phrase(
		"general:dataset_object_".$ds->confid));
}

sub get_item
{
	my( $self, $session, $value ) = @_;

	my $ds = $session->get_repository->get_dataset( 
			$self->get_property('datasetid') );

	return $ds->get_object( $session, $value );
}


sub get_input_elements
{   
	my( $self, $session, $value, $staff ) = @_;

	my $ex = $self->SUPER::get_input_elements( $session, $value, $staff );

	#my $buttons = $ex->[scalar @{$ex}-1]->[1]->{el};
	#$buttons->appendChild( $session->render_internal_buttons( $self->{name}."_null" => "Check ID's" ));
	my $buttons = $session->make_doc_fragment;
	$buttons->appendChild( 
		$session->render_internal_buttons( 
			$self->{name}."_null" => $session->phrase(
				"lib/metafield/itemref:lookup" )));
	my $bl = [];
	# pad the bottom line by one if this is a list to 
	# skip the column with the number in.
	if( $self->get_property( 'multiple' ) )
	{
		push @{$bl},{};
	}
	push @{$bl},{el=>$buttons,colspan=>3};
	push @{$ex}, $bl;

	return $ex;
}




######################################################################
1;
