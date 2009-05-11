######################################################################
#
# EPrints::Search::Condition::CanPass
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

B<EPrints::Search::Condition::CanPass> - "CanPass" abstract search condition

=head1 DESCRIPTION

Exists only during optimisation and is removed again.

=cut

package EPrints::Search::Condition::CanPass;

use EPrints::Search::Condition;

BEGIN
{
	our @ISA = qw( EPrints::Search::Condition );
}

use strict;

sub new
{
	my( $class, @params ) = @_;

	return bless { op=>"CANPASS", sub_ops=>\@params }, $class;
}

sub item_matches
{
	my( $self, $item ) = @_;

	EPrints::abort( "item_matches called on CanPass condition.");
}

sub process
{
	my( $self, $session, $i, $filter ) = @_;

	EPrints::abort( "process called on CanPass condition.");
}

sub optimise
{
	my( $self, $internal ) = @_;

	# do final clean up stuff, if any
	if( !$internal )
	{
		return $self->{sub_ops}->[0];
	}

	return $self;
}



sub get_op_val
{
	return 0;
}

1;
