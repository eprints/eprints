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

# sf2 - very, very similar than Int::validate_value...
sub validate_value
{
        my( $self, $value ) = @_;

	return 1 if( !defined $value );

# sf2 - problem: this calls Int::validate_value and of course the regex in Int will fail
#        $value = $self->SUPER::validate_value( $value );

	return 0 if( !EPrints::MetaField::validate_value( $self, $value ) );

        # sf2 - safer than using $self->property( 'multiple' );
        my $is_array = ref( $value ) eq 'ARRAY';

        my @valid_values;
        foreach my $single_value ( $is_array ?
                @$value :
                $value
        )
        {
                if( $single_value !~ /^[-+]?\d+\.?\d+$/ )
                {
                	$self->repository->debug_log( "field", "Non-floating point value passed to field: ".$self->dataset->id."/".$self->name );
#			if( $self->property( 'positive || signed?' ) )
#			{
#				if( $single_value < 0 ) ...
#			}
			return 0;
                }
        }

	return 1;
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
	$defaults{regexp} = qr/-?[0-9]+(\.[0-9]+)?/;
	return %defaults;
}

sub get_xml_schema_type
{
	return "xs:double";
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

