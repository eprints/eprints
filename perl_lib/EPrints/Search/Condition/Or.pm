######################################################################
#
# EPrints::Search::Condition::Or
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

B<EPrints::Search::Condition::Or> - "Or"

=head1 DESCRIPTION

Union of results of several sub conditions

=cut

package EPrints::Search::Condition::Or;

use EPrints::Search::Condition::Control;

BEGIN
{
	our @ISA = qw( EPrints::Search::Condition::Control );
}

use strict;

sub new
{
	my( $class, @params ) = @_;

	my $self = bless { op=>"OR", sub_ops=>\@params }, $class;

	$self->{prefix} = $self;
	$self->{prefix} =~ s/^.*:://;

	return $self;
}

sub optimise_specific
{
	my( $self, %opts ) = @_;

	my $keep_ops = [];
	foreach my $sub_op ( @{$self->{sub_ops}} )
	{
		# {ANY} OR TRUE is always TRUE
		return $sub_op if $sub_op->{op} eq "TRUE";

		# {ANY} OR FALSE is always {ANY}
		next if @{$keep_ops} > 0 && $sub_op->{op} eq "FALSE";
		
		push @{$keep_ops}, $sub_op;
	}
	$self->{sub_ops} = $keep_ops;

	return $self if @{$self->{sub_ops}} == 1;

	my $dataset = $opts{dataset};

	my %tables;
	$keep_ops = [];
	foreach my $sub_op ( @{$self->{sub_ops}} )
	{
		my $inner_dataset = $sub_op->dataset;
		my $table = $sub_op->table;
		# either don't need a LEFT JOIN (e.g. TRUE) or is on the main table
		if( !defined $inner_dataset || $table eq $dataset->get_sql_table_name )
		{
			push @$keep_ops, $sub_op;
		}
		else
		{
			push @{$tables{$table}||=[]}, $sub_op;
		}
	}

	foreach my $table (keys %tables)
	{
		push @$keep_ops, EPrints::Search::Condition::SubQuery->new(
				$tables{$table}->[0]->dataset,
				@{$tables{$table}}
			);
	}
	$self->{sub_ops} = $keep_ops;

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

	my %tables;

	foreach my $sub_op ( $self->ordered_ops )
	{
		$sub_op->get_query_joins( $joins, %opts );
		# note the tables used by this sub-op (if any)
		if( defined $sub_op->{join} && defined $sub_op->{join}->{table} )
		{
			push @{$tables{$sub_op->{join}->{table}}||=[]}, $sub_op;
		}
	}

	# performing an OR using table joins is very inefficient compared to
	# table.column = 'foo' OR table.column = 'bar'
	# The following code collapses table join ORs into a logical OR

	my %remove;
	while(my( $table, $sub_ops ) = each %tables)
	{
		for(my $i = 1; $i < @$sub_ops; ++$i)
		{
			$remove{$sub_ops->[$i]->{join}->{alias}} = 1;
			$sub_ops->[$i]->{join} = $sub_ops->[0]->{join};
		}
	}

	foreach my $datasetid (keys %$joins)
	{
		my $multiple = $joins->{$datasetid}->{multiple} || [];
		@$multiple = grep { !exists( $remove{$_->{alias}} ) } @$multiple;
	}
}

sub get_query_logic
{
	my( $self, %opts ) = @_;

	my @logic;
	foreach my $sub_op ( $self->ordered_ops )
	{
		push @logic, $sub_op->get_query_logic( %opts );
	}

	return "(" . join(") OR (", @logic) . ")";
}

sub joins
{
	my( $self, %opts ) = @_;

	my $db = $opts{session}->get_database;
	my $dataset = $opts{dataset};

	my %joins;
	foreach my $sub_op ( @{$self->{sub_ops}} )
	{
		foreach my $join ( $sub_op->joins( %opts ) )
		{
			$join->{type} = "left";
			$joins{$join->{alias}} = $join;
		}
	}

	return values %joins;
}

sub logic
{
	my( $self, %opts ) = @_;

	return "(" . join(" OR ", map { $_->logic( %opts ) } @{$self->{sub_ops}}) . ")";
}

1;
