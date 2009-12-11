######################################################################
#
# EPrints::Search::Condition::And
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

B<EPrints::Search::Condition::And> - Intersect results of several sub-conditions

=head1 DESCRIPTION

Intersect the results of sub-conditions.

=cut

package EPrints::Search::Condition::And;

use EPrints::Search::Condition::Control;
use Scalar::Util;

@ISA = qw( EPrints::Search::Condition::Control );

use strict;

sub new
{
	my( $class, @params ) = @_;

	my $self = bless { op=>"AND", sub_ops=>\@params }, $class;

	$self->{prefix} = $self->{op}.($self+0)."_";

	return $self;
}

sub optimise_specific
{
	my( $self, %opts ) = @_;

	my $keep_ops = [];
	foreach my $sub_op ( @{$self->{sub_ops}} )
	{
		# if an OR contains TRUE or an
		# AND contains FALSE then we can
		# cancel it all out.
		return $sub_op if $sub_op->{op} eq "FALSE";

		# just filter these out
		next if @$keep_ops > 0 && $sub_op->{op} eq "TRUE";
		
		push @{$keep_ops}, $sub_op;
	}
	$self->{sub_ops} = $keep_ops;

	return $self if @{$self->{sub_ops}} == 1;

	my $dataset = $opts{dataset};

	my %tables;
	$keep_ops = [];
	foreach my $sub_op ( @{$self->{sub_ops}} )
	{
		my $table = $sub_op->table;
		# apply simple sub-ops directly to the main table
		if( !defined $table || $table eq $dataset->get_sql_table_name )
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
		if( @{$tables{$table}} == 1 )
		{
			push @$keep_ops, @{$tables{$table}};
		}
		else
		{
			push @$keep_ops, EPrints::Search::Condition::AndSubQuery->new(
					$tables{$table}->[0]->dataset,
					@{$tables{$table}}
				);
		}
	}
	$self->{sub_ops} = $keep_ops;

	return $self;
}

sub joins
{
	my( $self, %opts ) = @_;

	my $db = $opts{session}->get_database;
	my $dataset = $opts{dataset};

	my $alias = "and_".Scalar::Util::refaddr( $self );
	my $key_name = $dataset->get_key_field->get_sql_name;

	my @joins;

	# operations on the main table are applied directly in logic()
	my @intersects;
	my %seen;
	foreach my $sub_op ( @{$self->{sub_ops}} )
	{
		my $table = $sub_op->table;
		$table = "" if !defined $table;
		if(
			$sub_op->isa( "EPrints::Search::Condition::OrSubQuery" ) &&
			$table ne $opts{dataset}->get_sql_table_name
		  )
		{
			push @intersects, $sub_op->sql( %opts, key_alias => $key_name );
		}
		elsif( !$seen{$table} )
		{
			push @joins, $sub_op->joins( %opts );
			$seen{$table} = 1;
		}
	}

	my $i = 0;
	return @joins, map { {
		type => "inner",
		subquery => "($_)",
		alias => $alias . "_" . $i++,
		key => $key_name,
	} } @intersects;
}

sub logic
{
	my( $self, %opts ) = @_;

	my @logic;
	foreach my $sub_op (@{$self->{sub_ops}})
	{
		my $table = $sub_op->table;
		if(
		  !$sub_op->isa( "EPrints::Search::Condition::OrSubQuery" ) ||
		  $table eq $opts{dataset}->get_sql_table_name
		  )
		{
			push @logic, $sub_op->logic( %opts );
		}
	}

	return () if !@logic;

	return join(' AND ', @logic);
}

1;
