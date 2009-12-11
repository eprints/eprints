######################################################################
#
# EPrints::Search::Condition::AndSubQuery
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

B<EPrints::Search::Condition::AndSubQuery> - AndSubQuery

=head1 DESCRIPTION

SubQuery is used internally by the search optimisation to make OR queries on the same table more efficient.

=cut

package EPrints::Search::Condition::AndSubQuery;

use EPrints::Search::Condition::SubQuery;

@ISA = qw( EPrints::Search::Condition::SubQuery );

use strict;

sub joins
{
	my( $self, %opts ) = @_;

	my $db = $opts{session}->get_database;
	my $dataset = $opts{dataset};

	my $alias = "and_".Scalar::Util::refaddr( $self );
	my $key_name = $dataset->get_key_field->get_sql_name;

	# operations on the main table are applied directly in logic()
	my @intersects;
	foreach my $sub_op ( @{$self->{sub_ops}} )
	{
		push @intersects, $sub_op->sql( %opts, key_alias => $key_name );
	}

	my $i = 0;
	return map { {
		type => "inner",
		subquery => "($_)",
		alias => $alias . "_" . $i++,
		key => $key_name,
	} } @intersects;
}

sub logic
{
	return ();
}

1;
