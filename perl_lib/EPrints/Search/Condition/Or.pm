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
	my( $self ) = @_;

	my $keep_ops = [];
	foreach my $sub_op ( @{$self->{sub_ops}} )
	{
		# if an OR contains TRUE or an
		# AND contains FALSE then we can
		# cancel it all out.
		return $sub_op if( $sub_op->{op} eq "TRUE" );

		# just filter these out
		next if( $sub_op->{op} eq "FALSE" );
		
		push @{$keep_ops}, $sub_op;
	}
	$self->{sub_ops} = $keep_ops;

	my %tables;
	my @core;
	foreach my $sub_op ( @{$self->{sub_ops}} )
	{
		my $table = $sub_op->get_table;
		if( !defined $table )
		{
			push @core, $sub_op;
		}
		else
		{
			push @{$tables{$table}||=[]}, $sub_op;
		}
	}

	if( keys %tables > 1 )
	{
		my $keep_ops = \@core;
		foreach my $table (keys %tables)
		{
			push @$keep_ops, EPrints::Search::Condition::SubQuery->new(
					@{$tables{$table}}
				);
		}
		$self->{sub_ops} = $keep_ops;
	}

	return $self;
}

sub item_matches
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


1;
