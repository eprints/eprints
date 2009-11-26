######################################################################
#
# EPrints::Search::Condition::Pass
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

B<EPrints::Search::Condition::Pass> - "Pass" abstract search condition

=head1 DESCRIPTION

Exists only during optimisation and is removed again.

=cut

package EPrints::Search::Condition::Pass;

use EPrints::Search::Condition::True;

@ISA = qw( EPrints::Search::Condition::True );

use strict;

sub new
{
	my( $class, @params ) = @_;

	return bless { op=>"PASS" }, $class;
}

sub _item_matches
{
	my( $self, $item ) = @_;

	EPrints::abort( "item_matches called on Pass condition.");
}

sub get_op_val
{
	return 0;
}

1;
