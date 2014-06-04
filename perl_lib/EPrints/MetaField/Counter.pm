######################################################################
#
# EPrints::MetaField::Counter;
#
######################################################################
#
#
######################################################################

=pod

=head1 NAME

B<EPrints::MetaField::Counter> - an incrementing integer

=head1 DESCRIPTION

This field represents an integer whose default value is an incrementing integer (1,2,3 ...).

=over 4

=cut

package EPrints::MetaField::Counter;

use strict;
use warnings;

use EPrints::MetaField::Int;
our @ISA = qw( EPrints::MetaField::Int );

sub new
{
	my( $class, %args ) = @_;

	my $self = $class->SUPER::new( %args );

	if( !defined $self->property( 'sql_counter' ) )
	{
		$self->set_property( 'sql_counter', $self->name );
	}

	return $self;
}

sub get_property_defaults
{
	my( $self ) = @_;
	my %defaults = $self->SUPER::get_property_defaults;
#	$defaults{sql_counter} = $EPrints::MetaField::REQUIRED;
	$defaults{sql_counter} = $EPrints::MetaField::UNDEF;
	$defaults{import} = 0;
	return %defaults;
}

sub get_default_value
{
	my( $self, $session ) = @_;

	return $session->get_database->counter_next( $self->get_property( "sql_counter" ) );
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

