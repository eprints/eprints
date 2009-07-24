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
	my( $self, $session ) = @_;

	my $database = $session->get_database;
	my $tables = $self->SUPER::get_tables( $session );
	if( scalar @{$tables} )
	{
		# join to a second dataset
		return $self->run_tables( $session, $self->get_tables( $session ) );
	}

	my $where = $database->quote_identifier("fieldword")." = ".$database->quote_value( 
			$self->{field}->get_sql_name.":".$self->{params}->[0] );
	return $session->get_database->get_index_ids( $self->get_table, $where );
}

sub get_tables
{
	my( $self, $session ) = @_;

	my $tables = $self->SUPER::get_tables( $session );
	my $database = $session->get_database;
	# otherwise joined tables on an index -- not efficient but this will work...
	my $where = "(".$database->quote_identifier($EPrints::Search::Condition::TABLEALIAS,"field")." = ".$database->quote_value( $self->{field}->get_sql_name );
	$where .= " AND ".$database->quote_identifier($EPrints::Search::Condition::TABLEALIAS,"word")." = ".$database->quote_value( $self->{params}->[0] ).")"; 
	
	push @{$tables}, {
		left => $self->{field}->get_dataset->get_key_field->get_name, 
		where => $where,
		table => $self->{field}->get_dataset->get_sql_rindex_table_name,
	};

	return $tables;
}

sub get_op_val
{
	return 1;
}

sub get_query_joins
{
	my( $self, $joins, %opts ) = @_;

	my $field = $self->{field};
	my $dataset = $field->{dataset};

	$joins->{$dataset->confid} ||= { dataset => $dataset };
	$joins->{$dataset->confid}->{'multiple'} ||= [];

	my $table = $dataset->get_sql_rindex_table_name( $field );
	my $idx = scalar(@{$joins->{$dataset->confid}->{'multiple'} ||= []});
	$self->{alias} = $idx . "_" . $table;
	push @{$joins->{$dataset->confid}->{'multiple'}}, {
		table => $table,
		alias => $self->{alias},
		key => $dataset->get_key_field->get_sql_name,
	};
}

sub get_query_logic
{
	my( $self, %opts ) = @_;

	my $db = $opts{session}->get_database;
	my $field = $self->{field};
	my $dataset = $field->{dataset};

	my $q_table = $db->quote_identifier($self->{alias});
	my $q_fieldname = $db->quote_identifier("field");
	my $q_fieldvalue = $db->quote_value($field->get_sql_name);
	my $q_word = $db->quote_identifier("word");
	my $q_value = $db->quote_value( $self->{params}->[0] );

	return "($q_table.$q_fieldname = $q_fieldvalue AND $q_table.$q_word = $q_value)";
}

1;
