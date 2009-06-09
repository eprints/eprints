######################################################################
#
# EPrints::Search::Condition::IsNull
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

B<EPrints::Search::Condition::IsNull> - "IsNull" search condition

=head1 DESCRIPTION

Matches items where the field is null.

=cut

package EPrints::Search::Condition::IsNull;

use EPrints::Search::Condition;

BEGIN
{
	our @ISA = qw( EPrints::Search::Condition );
}

use strict;

sub new
{
	my( $class, @params ) = @_;

	my $self = {};
	$self->{op} = "is_null";
	$self->{dataset} = shift @params;
	$self->{field} = shift @params;
	$self->{params} = \@params;

	return bless $self, $class;
}




sub item_matches
{
	my( $self, $item ) = @_;

	return $item->is_set( $self->{field}->get_name );
}

sub process
{
	my( $self, $session ) = @_;

	my $database = $session->get_database;
	my $tables = $self->SUPER::get_tables( $session );
	my $sql_col = $self->{field}->get_sql_name;

	my $where;
	if( $self->{field}->is_type( "date", "time" ) )
	{
		$where = "(".$database->quote_identifier($EPrints::Search::Condition::TABLEALIAS,"${sql_col}_year")." IS NULL)";
	}
	else
	{
		$where = "(".$database->quote_identifier($EPrints::Search::Condition::TABLEALIAS,$sql_col)." IS NULL OR ";
		$where .= $database->quote_identifier($EPrints::Search::Condition::TABLEALIAS,$sql_col)." = '')";
	}

	push @{$tables}, {
		left => $self->{field}->get_dataset->get_key_field->get_name, 
		where => $where,
		table => $self->{field}->get_property( "multiple" ) 
			? $self->{field}->get_dataset->get_sql_sub_table_name( $self->{field} )
			: $self->{field}->get_dataset->get_sql_table_name() 
	};

	return $tables;
}

sub get_op_val
{
	return 4;
}

1;
