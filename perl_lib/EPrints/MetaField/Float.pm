######################################################################
#
# EPrints::MetaField::Float;
#
######################################################################
#
#
######################################################################

=pod

=head1 NAME

B<EPrints::MetaField::Float> - no description

=head1 DESCRIPTION

not done

=over 4

=cut

package EPrints::MetaField::Float;

use strict;
use warnings;

BEGIN
{
	our( @ISA );

	@ISA = qw( EPrints::MetaField::Int );
}

use EPrints::MetaField::Int;

# does not yet support searching.

sub get_sql_type
{
	my( $self, $session ) = @_;

	return $session->get_database->get_column_type(
		$self->get_sql_name(),
		EPrints::Database::SQL_REAL,
		!$self->get_property( "allow_null" ),
		undef,
		undef,
		$self->get_sql_properties,
	);
}

sub ordervalue_basic
{
	my( $self , $value ) = @_;

	unless( EPrints::Utils::is_set( $value ) )
	{
		return "";
	}

	return sprintf( "%020f", $value );
}

sub get_property_defaults
{
	my( $self ) = @_;
	my %defaults = $self->SUPER::get_property_defaults;
	$defaults{text_index} = 0;
	return %defaults;
}

sub get_xml_schema_type
{
	return "xs:double";
}

sub render_xml_schema_type
{
	my( $self, $session ) = @_;

	return $session->make_doc_fragment;
}

sub form_value_basic
{
	my( $self, $session, $basename, $object ) = @_;

	my $value = $self->EPrints::MetaField::form_value_basic( $session, $basename, $object );

	return defined $value && $value =~ /^-?[0-9]*\.?[0-9]+$/ ? $value : undef;
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

