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

@ISA = qw( EPrints::Search::Condition );

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
	my( $self, %opts ) = @_;

	# flatten sub opts with the same type
	# so OR( A, OR( B, C ) ) becomes OR(A,B,C)
	my $keep_ops = [];
	foreach my $sub_op ( @{$self->{sub_ops}} )
	{
		if( $sub_op->{op} eq $self->{op} )
		{
			push @{$keep_ops}, @{$sub_op->{sub_ops}};
		}
		else
		{
			push @{$keep_ops}, $sub_op;
		}
	}
	$self->{sub_ops} = $keep_ops;

	$keep_ops = [];
	foreach my $sub_op ( @{$self->{sub_ops}} )
	{
		push @$keep_ops, $sub_op->optimise( %opts );
	}
	$self->{sub_ops} = $keep_ops;

	# control-specific condition stuff
	my $opt_condition = $self->optimise_specific( %opts );

	# only one sub option, just return it.
	# no sub_opts at all is a possibility if this optimised
	# to a non-control condition
	if( defined $opt_condition->{sub_ops} && scalar @{$opt_condition->{sub_ops}} == 1 )
	{
		return $opt_condition->{sub_ops}->[0];
	}

	return $opt_condition;
}

sub is_empty
{
	my( $self ) = @_;

	for(@{$self->{sub_ops}})
	{
		return 0 if !$_->is_empty();
	}

	return 1;
}

1;
