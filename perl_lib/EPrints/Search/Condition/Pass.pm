######################################################################
#
# EPrints::Search::Condition::Pass
#
######################################################################
#
#
######################################################################

=pod

=head1 NAME

B<EPrints::Search::Condition::Pass> - "Pass" abstract search condition

=head1 DESCRIPTION

Exists only during optimisation and is removed again.

=cut

package EPrints::Search::Condition::Pass;

use EPrints::Search::Condition;

@ISA = qw( EPrints::Search::Condition );

use strict;

sub new
{
	my( $class, @params ) = @_;

	return bless { op=>"PASS" }, $class;
}

sub is_empty
{
	my( $self ) = @_;

	return 1;
}

sub joins
{
	EPrints->abort( "Can't create table joins for PASS condition" );
}

sub logic
{
	EPrints->abort( "Can't create SQL logic for PASS condition" );
}

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

