######################################################################
#
# EPrints::MetaField::Bitint;
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

B<EPrints::MetaField::Bigint> - big integer

=head1 DESCRIPTION

Signed integer in the range -9223372036854775808 to 9223372036854775807.

=over 4

=cut

package EPrints::MetaField::Bigint;

use strict;
use warnings;

use EPrints::MetaField::Int;
our @ISA = qw( EPrints::MetaField::Int );

sub get_sql_type
{
	my( $self, $handle ) = @_;

	return $handle->get_database->get_column_type(
		$self->get_sql_name(),
		EPrints::Database::SQL_BIGINT,
		!$self->get_property( "allow_null" ),
		undef,
		undef,
		$self->get_sql_properties,
	);
}

######################################################################
1;
