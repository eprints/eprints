=head1 NAME

B<EPrints::MetaField::Parent> - parent object of subobject

=head1 DESCRIPTION

This virtual field provides access to the value of L<EPrints::DataObj::SubObject/parent>.

=over 4

=cut

package EPrints::MetaField::Parent;

use EPrints::MetaField;

@ISA = qw( EPrints::MetaField );

use strict;

sub is_virtual { 1 }

sub get_value
{
	my( $self, $dataobj ) = @_;

	# allow caching via set_value()
	my $parent = $dataobj->get_value_raw( $self->name );
	return $parent if defined $parent;

	# may be cached anyway via _parent
	return $dataobj->parent;
}

sub render_value
{
	my( $self, $repo, $dataobj ) = @_;

	return $dataobj->render_citation_link;
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

