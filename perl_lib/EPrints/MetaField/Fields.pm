######################################################################
#
# EPrints::MetaField::Fields;
#
######################################################################
#
#
######################################################################

=pod

=head1 NAME

B<EPrints::MetaField::Fields> - no description

=head1 DESCRIPTION

not done

=over 4

=cut

# set_name

package EPrints::MetaField::Fields;

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
	my( $self, $session ) = @_;

	my @tags = $self->get_unsorted_values( $session );

	return sort {
		EPrints::Utils::tree_to_utf8( $self->render_option( $session, $a ) ) cmp
		EPrints::Utils::tree_to_utf8( $self->render_option( $session, $b ) ) 
	} @tags;
}

sub get_unsorted_values
{
	my( $self, $session, $dataset, %opts ) = @_;

	my $ds = $session->dataset( 
			$self->get_property('datasetid') );

	my @types = ();
	foreach my $field ( $ds->get_fields )
	{
		next unless $field->get_property( "show_in_fieldlist" );
		push @types, $field->get_name;
	}

	return @types;
}
sub get_property_defaults
{
	my( $self ) = @_;
	my %defaults = $self->SUPER::get_property_defaults;
	$defaults{datasetid} = $EPrints::MetaField::REQUIRED;
	delete $defaults{options}; # inherrited but unwanted
	return %defaults;
}

sub get_search_group { return 'set'; }



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

