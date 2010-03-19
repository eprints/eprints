######################################################################
#
# EPrints::Search::Condition::Index
#
######################################################################
#
#  __COPYRIGHT__
#
# Copyright 2000-2008 University of Southampton. All Rights Reserved.
# 
#  __LICENSE__
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
