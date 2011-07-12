######################################################################
#
# EPrints::Search::Condition::Index
#
######################################################################
#
#
######################################################################

=pod

=head1 NAME

B<EPrints::Search::Condition::Index> - "Index" search condition

=head1 DESCRIPTION

Matches items with a matching search index value.

=cut

package EPrints::Search::Condition::Index;

use EPrints::Search::Condition::Comparison;

@ISA = qw( EPrints::Search::Condition::Comparison );

use strict;

sub new
{
	my( $class, @params ) = @_;

	return $class->SUPER::new( "index", @params );
}

sub table
{
	my( $self ) = @_;

	return undef if( !defined $self->{field} );

	return $self->{field}->{dataset}->get_sql_rindex_table_name;
}

sub joins
{
	my( $self, %opts ) = @_;

	my $prefix = $opts{prefix};
	$prefix = "" if !defined $prefix;

	my $field = $self->{field};
	if( !$field->{dataset}->indexable )
	{
		EPrints->abort( "Can not perform index query on non-indexed dataset for ".$field->{dataset}->base_id.".".$field->name );
	}

	my $db = $opts{session}->get_database;
	my $table = $self->table;
	my $key_field = $self->dataset->get_key_field;

	my( $join ) = $self->SUPER::joins( %opts );

	# joined via an intermediate table
	if( defined $join )
	{
		if( defined($join->{table}) && $join->{table} eq $table )
		{
			return $join;
		}
		# similar to a multiple table match in comparison
		return (
			$join,
			{
				type => "inner",
				table => $table,
				alias => "$prefix$table",
				logic => $db->quote_identifier( $join->{alias}, $key_field->get_sql_name )."=".$db->quote_identifier( "$prefix$table", $key_field->get_sql_name ),
			}
		);
	}
	else
	{
		# include this table and link it to the main table in logic
		return {
			type => "inner",
			table => $table,
			alias => "$prefix$table",
			logic => $db->quote_identifier( $opts{dataset}->get_sql_table_name, $key_field->get_sql_name )."=".$db->quote_identifier( "$prefix$table", $key_field->get_sql_name ),
			key => $key_field->get_sql_name,
		};
	}
}

sub logic
{
	my( $self, %opts ) = @_;

	my $prefix = $opts{prefix};
	$prefix = "" if !defined $prefix;

	my $db = $opts{session}->get_database;
	my $table = $prefix . $self->table;
	my $sql_name = $self->{field}->get_sql_name;

	return sprintf( "%s=%s AND %s=%s",
		$db->quote_identifier( $table, "field" ),
		$db->quote_value( $sql_name ),
		$db->quote_identifier( $table, "word" ),
		$db->quote_value( $self->{params}->[0] ) );
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

