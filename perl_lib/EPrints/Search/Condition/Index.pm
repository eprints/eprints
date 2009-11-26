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

sub _item_matches
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
	push @{$joins->{$dataset->confid}->{'multiple'}}, $self->{join} = {
		table => $table,
		alias => $idx . "_" . $table,
		key => $dataset->get_key_field->get_sql_name,
	};
}

sub get_query_logic
{
	my( $self, %opts ) = @_;

	my $db = $opts{session}->get_database;
	my $field = $self->{field};
	my $dataset = $field->{dataset};

	my $q_table = $db->quote_identifier($self->{join}->{alias});
	my $q_fieldname = $db->quote_identifier("field");
	my $q_fieldvalue = $db->quote_value($field->get_sql_name);
	my $q_word = $db->quote_identifier("word");
	my $q_value = $db->quote_value( $self->{params}->[0] );

	return "($q_table.$q_fieldname = $q_fieldvalue AND $q_table.$q_word = $q_value)";
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
		my $sql = defined $join->{subquery} ? $join->{subquery} : $db->quote_identifier( $join->{table} );
		$sql .= " INNER JOIN ".$db->quote_identifier( $table );
		$sql .= " ON ".$db->quote_identifier( $join->{alias}, $key_field->get_sql_name )."=".$db->quote_identifier( $table, $key_field->get_sql_name );
		$join->{subquery} = $sql;
		# delete $join->{alias}; # now a join so don't attempt to alias
		return $join;
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
