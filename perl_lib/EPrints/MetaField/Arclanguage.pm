######################################################################
#
# EPrints::MetaField::Arclanguage;
#
######################################################################
#
#
######################################################################

=pod

=head1 NAME

B<EPrints::MetaField::Arclanguage> - no description

=head1 DESCRIPTION

not done

=over 4

=cut

# type_set

package EPrints::MetaField::Arclanguage;

use strict;
use warnings;

BEGIN
{
	our( @ISA );

	@ISA = qw( EPrints::MetaField::Set );
}

use EPrints::MetaField::Set;

sub tags
{
	my( $self, $repository ) = @_;

	return @{$repository->config( "languages" )};
}

sub get_unsorted_values
{
	my( $self, $repository, $dataset, %opts ) = @_;

	return @{$repository->config( "languages" )};
}

sub render_option
{
	my( $self, $repository, $value ) = @_;

	return $repository->render_type_name( 'languages', $value );
}

sub get_property_defaults
{
	my( $self ) = @_;
	my %defaults = $self->SUPER::get_property_defaults;
	delete $defaults{options}; # inherrited but unwanted
	return %defaults;
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

