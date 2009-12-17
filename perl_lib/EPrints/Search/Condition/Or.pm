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
use Scalar::Util;

@ISA = qw( EPrints::Search::Condition::Control );

use strict;

sub new
{
	my( $class, @params ) = @_;

	@params = grep { !$_->is_empty } @params;

	my $self = bless { op=>"OR", sub_ops=>\@params }, $class;

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
		next if $sub_op->{op} eq "FALSE";
		
		push @{$keep_ops}, $sub_op;
	}
	$self->{sub_ops} = $keep_ops;

	return EPrints::Search::Condition::False->new() if $self->is_empty;

	return $self if @{$self->{sub_ops}} == 1;

	my $dataset = $opts{dataset};

	my %tables;
	$keep_ops = [];
	foreach my $sub_op ( @{$self->{sub_ops}} )
	{
		my $table = $sub_op->table;
		# doesn't need a sub-query
		if( !defined $table )
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
		# must do every condition using a subquery, otherwise we would need
		# LEFT JOINs
		push @$keep_ops, EPrints::Search::Condition::OrSubQuery->new(
				$tables{$table}->[0]->dataset,
				@{$tables{$table}},
			);
	}
	$self->{sub_ops} = $keep_ops;

	return $self;
}

sub joins
{
	my( $self, %opts ) = @_;

	my $db = $opts{session}->get_database;
	my $dataset = $opts{dataset};

	my $alias = "or_".Scalar::Util::refaddr( $self );
	my $key_name = $dataset->get_key_field->get_sql_name;

	my @unions;
	foreach my $sub_op ( @{$self->{sub_ops}} )
	{
		push @unions, $sub_op->sql( %opts, key_alias => $key_name );
	}

	my $sql = "(".join(' UNION ', @unions).")";

	return {
		type => "inner",
		subquery => $sql,
		alias => $alias,
		key => $key_name,
	};
}

sub logic
{
	my( $self, %opts ) = @_;

	return ();
}

1;
