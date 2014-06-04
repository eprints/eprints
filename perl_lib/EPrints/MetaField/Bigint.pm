######################################################################
#
# EPrints::MetaField::Bitint;
#
######################################################################
#
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
	my( $self, $repository ) = @_;

	return $repository->get_database->get_column_type(
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

