######################################################################
#
# EPrints::MetaField::Boolean;
#
######################################################################
#
#
######################################################################

=pod

=head1 NAME

B<EPrints::MetaField::Boolean> - no description

=head1 DESCRIPTION

not done

=over 4

=cut

package EPrints::MetaField::Boolean;

use strict;
use warnings;

BEGIN
{
	our( @ISA );

	@ISA = qw( EPrints::MetaField );
}

use EPrints::MetaField;

sub validate_value
{
	my( $self, $value ) = @_;

	return 1 if( !defined $value );

	return 0 if( !$self->SUPER::validate_value( $value ) );

        my $is_array = ref( $value ) eq 'ARRAY';

        foreach my $single_value ( $is_array ?
                @$value :
                $value
        )
        {
                return 0 if( !$self->validate_type( $single_value ) );

		if( !($single_value eq 'TRUE' || $single_value eq 'FALSE' ) )
		{
                        $self->repository->debug_log( "field", "Invalid boolean value passed to field: ".$self->dataset->id."/".$self->name );
			return 0;
		}
        }

	return 1;
}

sub get_sql_type
{
	my( $self, $session ) = @_;

	# Could be a 'SET' on MySQL/Postgres
	return $session->get_database->get_column_type(
		$self->get_sql_name(),
		EPrints::Database::SQL_VARCHAR,
		!$self->get_property( "allow_null" ),
		5, # 'TRUE' or 'FALSE'
		undef,
		$self->get_sql_properties,
	);
}

sub get_index_codes
{
	my( $self, $session, $value ) = @_;

	return( [], [], [] );
}

sub get_unsorted_values
{
	my( $self, $session, $dataset, %opts ) = @_;

	return [ "TRUE", "FALSE" ];
}


sub get_search_conditions_not_ex
{
	my( $self, $session, $dataset, $search_value, $match, $merge,
		$search_mode ) = @_;
	
	return EPrints::Search::Condition->new( 
		'=', 
		$dataset,
		$self, 
		$search_value );
}

sub get_property_defaults
{
	my( $self ) = @_;
	my %defaults = $self->SUPER::get_property_defaults;
	$defaults{text_index} = 0;
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

