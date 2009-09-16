######################################################################
#
# EPrints::MetaField::Uuid;
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

B<EPrints::MetaField::Uuid> - globally unique identifier

=head1 DESCRIPTION

This field type automatically generates a UUID based on L<APR::UUID>, which is
part of mod_perl. The UUID is prepended with "urn:uuid:" to namespace it to the
global system of UUID URIs.

=over 4

=cut

package EPrints::MetaField::Uuid;

use APR::UUID;
use EPrints::MetaField::Text;

@ISA = qw( EPrints::MetaField::Text );

use strict;

sub get_property_defaults
{
	my( $self ) = @_;
	my %defaults = $self->SUPER::get_property_defaults;
	$defaults{text_index} = 0;
	$defaults{maxlength} = 45;
	return %defaults;
}

sub get_default_value
{
	my( $self, $session ) = @_;

	return "urn:uuid:" . APR::UUID->new->format();
}

######################################################################
1;
