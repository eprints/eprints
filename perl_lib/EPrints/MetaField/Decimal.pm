=for Pod2Wiki

=head1 NAME

EPrints::MetaField::Decimal - non-rounding decimals

=head1 DESCRIPTION

Provides the ANSI DECIMAL SQL type. DECIMALs are fractional values that are
stored as integers, avoiding the risk of rounding errors. These are typically
used to store currency values where accounting rules require that values
exactly match (i.e. you can't gain or lose pennies due to rounding).

=head1 PROPERTIES

=over 4

=item integer = 16

Digits stored before the decimal point.

=item fractional = 2

Digits stored after the decimal point.

=back

=head1 METHODS

=over 4

=cut

package EPrints::MetaField::Decimal;

use base qw ( EPrints::MetaField::Float );

use strict;

sub get_sql_type
{
	my( $self, $session ) = @_;

	return $session->get_database->get_column_type(
		$self->get_sql_name(),
		EPrints::Database::SQL_DECIMAL,
		!$self->get_property( "allow_null" ),
		$self->property('integer'),
		$self->property('fractional'),
		$self->get_sql_properties,
	);
}

sub get_max_input_size
{
	my( $self ) = @_;

	return $self->property( "integer" ) + $self->property( "fractional" ) + 2; # sign + decimal point
}

sub ordervalue_basic
{
	my( $self , $value ) = @_;

	return "" if !EPrints::Utils::is_set( $value );

	return sprintf('%'.($self->property('integer')+1).".".$self->property('fractional').'f', $value);
}

sub render_search_input
{
	my( $self, $session, $searchfield ) = @_;
	
	return $session->render_input_field(
				class => "ep_form_text",
				name=>$searchfield->get_form_prefix,
				value=>$searchfield->get_value,
				size=>9,
				maxlength=>$self->get_max_input_size );
}

sub get_property_defaults
{
	my( $self ) = @_;
	my %defaults = $self->SUPER::get_property_defaults;
	$defaults{integer} = 16;
	$defaults{fractional} = 2;
	return %defaults;
}

######################################################################
1;

=back

=head1 COPYRIGHT

=for COPYRIGHT BEGIN

Copyright 2000-2013 University of Southampton.

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

