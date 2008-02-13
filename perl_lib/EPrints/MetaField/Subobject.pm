######################################################################
#
# EPrints::MetaField::Subobject;
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

B<EPrints::MetaField::Subobject> - Sub Object an object.

=head1 DESCRIPTION

This is an abstract field which represents an item, or list of items,
in another dataset, but which are a sub part of the object to which
this field belongs, and have no indepentent status.

For example: Documents are part of EPrints.

=over 4

=cut

package EPrints::MetaField::Subobject;

use strict;
use warnings;

BEGIN
{
	our( @ISA );

	@ISA = qw( EPrints::MetaField );
}

use EPrints::MetaField;

sub get_sql_type
{
	my( $self, $session, $notnull ) = @_;

	return undef;
}


# This type of field is virtual.
sub is_virtual
{
	my( $self ) = @_;

	return 1;
}

######################################################################

sub get_property_defaults
{
	my( $self ) = @_;

	my %defaults = $self->SUPER::get_property_defaults;
	$defaults{datasetid} = $EPrints::MetaField::REQUIRED; 
	$defaults{show_in_fieldlist} = 0;

	return %defaults;
}

######################################################################
1;
