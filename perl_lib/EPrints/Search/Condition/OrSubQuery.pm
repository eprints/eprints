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

SubQuery is used internally by the search optimisation to make OR queries on the same table more efficient.

=cut

package EPrints::Search::Condition::OrSubQuery;

use EPrints::Search::Condition::SubQuery;

@ISA = qw( EPrints::Search::Condition::SubQuery );

use strict;

sub logic
{
	my( $self, %opts ) = @_;

	return "(" . join(" OR ", map { $_->logic( %opts ) } @{$self->{sub_ops}} ) . ")";
}

1;
