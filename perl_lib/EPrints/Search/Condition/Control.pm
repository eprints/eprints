######################################################################
#
# EPrints::Search::Condition::Control
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

B<EPrints::Search::Condition::Control> - Control structure

=head1 DESCRIPTION

Intersect the results of sub-conditions.

=cut

package EPrints::Search::Condition::Control;

use EPrints::Search::Condition;

BEGIN
{
	our @ISA = qw( EPrints::Search::Condition );
}

use strict;

sub new
{
	my( $class, @params ) = @_;

	EPrints::abort( "new called on abstract Control condition.");
}

# internal means don't strip canpass off the front.
# nb. this is only good for AND and OR. Not would need a custom version of this.
sub optimise
{
	my( $self, $internal ) = @_;

	my $tree = $self;

	my @new_sub_ops = ();
	foreach my $sub_op ( @{$tree->{sub_ops}} )
	{
		push @new_sub_ops, $sub_op->optimise( 1 );
	}
	$tree->{sub_ops} = \@new_sub_ops;



	# strip passes 
	my @sureops = ();
	foreach my $sub_op ( @{$tree->{sub_ops}} )
	{
		next if( $sub_op->{op} eq "PASS" );
		push @sureops, $sub_op;
	}

	$tree->{sub_ops} = \@sureops;

	# flatten sub opts with the same type
	# so OR( A, OR( B, C ) ) becomes OR(A,B,C)
	my $flat_ops = [];
	foreach my $sub_op ( @{$tree->{sub_ops}} )
	{
		if( $sub_op->{op} eq $tree->{op} )
		{
			push @{$flat_ops}, 
				@{$sub_op->{sub_ops}};
			next;
		}
		
		push @{$flat_ops}, $sub_op;
	}
	$tree->{sub_ops} = $flat_ops;


	# control-specific condition stuff
	$tree = $tree->optimise_specific();


	# no items, match nothing.
	if( !defined $tree->{sub_ops} || scalar @{$tree->{sub_ops}} == 0 )
	{
		return EPrints::Search::Condition::Pass->new();
	}

	# only one sub option, just return it.
	if( scalar @{$tree->{sub_ops}} == 1 )
	{
		return $tree->{sub_ops}->[0];
	}

	return $tree;
}

######################################################################
=pod

=item @ops = $scond->ordered_ops

AND or OR conditions only. Return the sub conditions ordered by 
approximate ease. This is used to make sure a TRUE or FALSE is
prcessed before an index-lookup, and that everthing else is is tried 
before a grep OP (which uses LIKE). This means that it can often
give up before the expensive operation is needed.

=cut
######################################################################

sub ordered_ops
{
	my( $self ) = @_;

	return sort { $a->get_op_val <=> $b->get_op_val } @{$self->{sub_ops}};
}

# special handling if first item in the list is
sub item_matches
{
	my( $self, $item ) = @_;

	EPrints::abort( "item_matches called on abstract Control condition.");
}

sub process
{
	my( $self, $session, $i, $filter ) = @_;

	EPrints::abort( "process called on abstract Control condition.");
}

sub get_op_val
{
	return 3;
}

1;
