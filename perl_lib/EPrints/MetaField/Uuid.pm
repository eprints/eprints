######################################################################
#
# EPrints::MetaField::Uuid;
#
######################################################################
#
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
use EPrints::MetaField::Id;

@ISA = qw( EPrints::MetaField::Id );

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

