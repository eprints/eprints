######################################################################
#
# EPrints::MetaField::Int;
#
######################################################################
#
#
######################################################################

=pod

=head1 NAME

B<EPrints::MetaField::Int> - no description

=head1 DESCRIPTION

not done

=over 4

=cut

package EPrints::MetaField::Int;

use strict;
use warnings;

BEGIN
{
	our( @ISA );

	@ISA = qw( EPrints::MetaField );
}

use EPrints::MetaField;

# sf2 - enforce checks
# returns the valid(-ated) values
sub validate_value
{
	my( $self, $value ) = @_;

	# undef is valid
	return 1 if( !defined $value );

	return 0 if( !$self->SUPER::validate_value( $value ) );

	# sf2 - safer than using $self->property( 'multiple' );
	my $is_array = ref( $value ) eq 'ARRAY';

	my @valid_values;
	foreach my $single_value ( $is_array ?
		@$value :
		$value
	)
	{
		return 0 if( !$self->validate_type( $single_value ) );
		if( $single_value !~ /^[-+]?\d+$/ )
		{
			$self->repository->debug_log( "field", "Non-integer value passed to field: ".$self->dataset->id."/".$self->name );
			return 0;
		}
	}

	return 1;
}

sub validate_type
{
	my( $self, $value ) = @_;

	return 1 if( !defined $value || ref( $value ) eq '' );

	$self->repository->log( "Non-scalar value passed to field: ".$self->dataset->id."/".$self->name );

	return 0;
}

sub get_sql_type
{
	my( $self, $session ) = @_;

	return $session->get_database->get_column_type(
		$self->get_sql_name(),
		EPrints::Database::SQL_INTEGER,
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

	# just in case we still use eprints in year 200k 
	my $pad = $self->get_property( "digits" );
	return sprintf( "%0".$pad."d",$value );
}

sub get_search_conditions_not_ex
{
	my( $self, $session, $dataset, $search_value, $match, $merge,
		$search_mode ) = @_;
	
	# N
	# N..
	# ..N
	# N..N

	my $regexp = $self->property( "regexp" );
	my $range = qr/-|(?:\.\.)/;

	if( $search_value =~ m/^$regexp$/ )
	{
		return EPrints::Search::Condition->new( 
			'=', 
			$dataset,
			$self, 
			$search_value );
	}

	my( $lower, $higher ) = $search_value =~ m/^($regexp)?$range($regexp)?$/;

	my @r = ();
	if( defined $lower )
	{
		push @r, EPrints::Search::Condition->new( 
				'>=',
				$dataset,
				$self,
				$1);
	}
	if( defined $higher )
	{
		push @r, EPrints::Search::Condition->new( 
				'<=',
				$dataset,
				$self,
				$2 );
	}

	if( !@r )
	{
		return EPrints::Search::Condition->new( 'FALSE' );
	}
	elsif( @r == 1 )
	{
		return $r[0];
	}
	else
	{
		return EPrints::Search::Condition->new( "AND", @r );
	}
}

sub get_search_group { return 'number'; } 

sub get_property_defaults
{
	my( $self ) = @_;
	my %defaults = $self->SUPER::get_property_defaults;
	$defaults{digits} = $EPrints::MetaField::FROM_CONFIG;
	$defaults{text_index} = 0;
	$defaults{regexp} = qr/-?[0-9]+/;

	return %defaults;
}

sub get_xml_schema_type
{
	return "xs:integer";
}

# integer fields must be NULL or a number, can't be ''
sub xml_to_epdata_basic
{
	my( $self, $session, $xml, %opts ) = @_;

	my $value = EPrints::Utils::tree_to_utf8( scalar $xml->childNodes );

	return EPrints::Utils::is_set( $value ) ? $value : undef;
}

sub sql_row_from_value
{
	my( $self, $session, $value ) = @_;

	return( $value );
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

