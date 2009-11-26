######################################################################
#
# EPrints::Search::Condition::SubQuery
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

B<EPrints::Search::Condition::SubQuery> - SubQuery

=head1 DESCRIPTION

A SQL sub-query, which is required to efficiently perform ORs over multiple tables.

=cut

package EPrints::Search::Condition::SubQuery;

use EPrints::Search::Condition::Or;
use Scalar::Util qw( refaddr );

@ISA = qw( EPrints::Search::Condition::Or );

use strict;

sub new
{
	my( $class, @params ) = @_;

	my $self = bless {
			op => "SubQuery",
			dataset => shift(@params),
			sub_ops => \@params
		}, $class;

	return $self;
}

sub _item_matches
{
	my( $self, $item ) = @_;

	foreach my $sub_op ( $self->ordered_ops )
	{
		my $r = $sub_op->item_matches( $item );
		return( 1 ) if( $r == 1 );
	}

	return( 0 );
}

sub get_query_joins
{
	my( $self, $joins, %opts ) = @_;

	my $db = $opts{session}->get_database;

	my $sub_joins = {};

	foreach my $sub_op ( @{$self->{sub_ops}} )
	{
		$sub_op->get_query_joins( $sub_joins, %opts );
		$sub_op->{join} = $self->{sub_ops}->[0]->{join};
	}

	my $join = $self->{sub_ops}->[0]->{join};

	my $key_field = $opts{dataset}->get_key_field;

	my $table = $join->{table};
	my $key = $key_field->get_sql_name;

	my $dataset = $self->{sub_ops}->[0]->{field}->{dataset};

	my $sql = "";
	
	# need a join path
	if( $opts{dataset}->confid ne $dataset->confid )
	{
		my( $left_key, $right_key ) = $self->join_keys( $opts{dataset}, $dataset );
		# my $left_table = $opts{dataset}->get_sql_table_name;
		my $right_table = $self->{sub_ops}->[0]->table;
		$table = $right_table;
		$key = $right_key;
		# multiple
		if( $right_table ne $dataset->get_sql_table_name )
		{
			my $middle_table = $dataset->get_sql_table_name;
			my $middle_key = $dataset->get_key_field->get_sql_name;
			$sql .= "SELECT ".$db->quote_identifier($middle_table, $right_key)." FROM ".$db->quote_identifier($middle_table)." INNER JOIN ".$db->quote_identifier($right_table)." ".$db->quote_identifier($join->{alias})." ON ".$db->quote_identifier($middle_table, $middle_key)."=".$db->quote_identifier($join->{alias}, $middle_key);
		}
		else
		{
			$sql .= "SELECT ".$db->quote_identifier($right_table, $right_key)." FROM ".$db->quote_identifier( $right_table )." ".$db->quote_identifier($join->{alias});
		}
	}
	else
	{
		$sql .= "SELECT ".$db->quote_identifier($key)." FROM ";
		$sql .= $db->quote_identifier($table)." ".$db->quote_identifier($join->{alias});
	}

	# calculate an alias for this SubQuery
	my $idx = scalar(@{$joins->{$opts{dataset}->confid}->{'multiple'} ||= []});
	my $alias = $idx . "_" . $table;

	# construct the sub-query 

	my @logic = map { $_->get_query_logic( %opts ) } @{$self->{sub_ops}};

	$sql .= " WHERE ".join(" OR ", @logic);

	$sql = "($sql)";

	push @{$joins->{$opts{dataset}->confid}->{'multiple'}}, $self->{join} = {
		table => $table,
		alias => $alias,
		key => $key,
		subquery => $sql,
	};
}

sub get_query_logic
{
	my( $self, %opts ) = @_;

	return $opts{session}->get_database->quote_identifier( $self->{join}->{alias}, $self->{join}->{key} )." is not Null";
}

sub get_op_val
{
	return 3;
}

sub _sql
{
	my( $self, %opts ) = @_;

	my $db = $opts{session}->get_database;

	my $dataset = $opts{dataset};
	my $inner_dataset = $self->{dataset};

	my $key_alias = delete $opts{key_alias};

	my $sql = "";

	my $sub_op = $self->{sub_ops}->[0];

	my( $join ) = $sub_op->joins( %opts );

	$sql .= "SELECT ".$db->quote_identifier( $join->{key} )." ".$db->quote_identifier( $key_alias );

	$sql .= " FROM ".(defined( $join->{subquery} ) ? $join->{subquery} : $db->quote_identifier( $join->{table} ));

	if( defined $join->{alias} )
	{
		$sql .= " ".$db->quote_identifier( $join->{alias} );
	}

	my @logic = map { $_->logic( %opts ) } @{$self->{sub_ops}};
	if( @logic )
	{
		$sql .= " WHERE ".join(" OR ", @logic);
	}

	return $sql;
}

sub joins
{
	my( $self, %opts ) = @_;

	my $db = $opts{session}->get_database;
	my $dataset = $opts{dataset};
	my $key_alias = $self->key_alias( %opts );

	my $sql = "(" . $self->_sql( %opts, key_alias => $key_alias ) . ")";

	return {
		type => "left",
		table => $self->alias,
		subquery => $sql,
		alias => $self->alias,
		key => $key_alias,
	};
}

sub logic
{
	my( $self, %opts ) = @_;

	my $db = $opts{session}->get_database;

	my $key_alias = $self->key_alias( %opts );

	return $db->quote_identifier( $self->alias, $key_alias )." IS NOT NULL";
}

sub alias
{
	my( $self ) = @_;

	my $alias = lc(ref($self));
	$alias =~ s/^.*:://;
	$alias .= "_".refaddr($self);

	return $alias;
}

sub key_alias
{
	my( $self, %opts ) = @_;

	my $dataset = $opts{dataset};

	return $dataset->get_key_field->get_sql_name . "_" . refaddr($self);
}

1;
