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
	$self->{op} = "index";
	$self->{dataset} = shift @params;
	$self->{field} = shift @params;
	$self->{params} = \@params;

	return bless $self, $class;
}

sub get_table
{
	my( $self ) = @_;

	return undef if( !defined $self->{field} );

	return $self->{dataset}->get_sql_index_table_name;
}



sub item_matches
{
	my( $self, $item ) = @_;

	my( $codes, $grepcodes, $badwords ) =
		$self->{field}->get_index_codes(
			$item->get_session,
			$item->get_value( $self->{field}->get_name ) );

	foreach my $code ( @{$codes} )
	{
		return( 1 ) if( $code eq $self->{params}->[0] );
	}

	return( 0 );
}

sub process
{
	my( $self, $session, $i, $filter ) = @_;

	$i = 0 unless( defined $i );

	my $tables = $self->get_tables( $session );
	my $database = $session->get_database;

	if( scalar @{$tables} == 0 )
	{
		my $where = $database->quote_identifier("fieldword")." = ".$database->quote_value( 
			$self->{field}->get_sql_name.":".$self->{params}->[0] );
		return $session->get_database->get_index_ids( $self->get_table, $where );
	}

	# otherwise joined tables on an index -- not efficient but this will work...
	my $where = $database->quote_identifier($EPrints::Search::Condition::TABLEALIAS,"field")." = ".$database->quote_value( $self->{field}->get_sql_name );
	$where .= " AND ".$database->quote_identifier($EPrints::Search::Condition::TABLEALIAS,"word")." = ".$database->quote_value( $self->{params}->[0] ); 
	
	push @{$tables}, {
		left => $self->{field}->get_dataset->get_key_field->get_name, 
		where => $where,
		table => $self->{field}->get_dataset->get_sql_rindex_table_name,
	};

	return $self->run_tables( $session, $tables );
}

sub get_op_val
{
	return 1;
}

1;
