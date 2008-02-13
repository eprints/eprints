######################################################################
#
# EPrints::MetaField::File;
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

B<EPrints::MetaField::File> - File in the file system.

=head1 DESCRIPTION

This is an abstract field which represents a directory in the 
filesystem. It is mostly used by the import and export systems.

For example: Documents have files.

=over 4

=cut

package EPrints::MetaField::File;

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

sub get_property_defaults
{
	my( $self ) = @_;

	my %defaults = $self->SUPER::get_property_defaults;
	$defaults{show_in_fieldlist} = 0;
	#$defaults{datasetid} = $EPrints::MetaField::REQUIRED; 

	return %defaults;
}

######################################################################
1;
