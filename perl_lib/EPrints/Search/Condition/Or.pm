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

	return bless { op=>"OR", sub_ops=>\@params }, $class;
}

sub optimise_specific
{
	my( $self ) = @_;

	my $tree = $self;

	my $keep_ops = [];
	foreach my $sub_op ( @{$tree->{sub_ops}} )
	{
		# if an OR contains TRUE or an
		# AND contains FALSE then we can
		# cancel it all out.
		return $sub_op if( $sub_op->{op} eq "TRUE" );

		# just filter these out
		next if( $sub_op->{op} eq "FALSE" );
		
		push @{$keep_ops}, $sub_op;
	}
	$tree->{sub_ops} = $keep_ops;

	return $tree;
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

sub get_query_tree
{
	my( $self, $session, $qdata, $mergemap ) = @_;

	# if nested or's then use existing $mergemap, otherwise create one.
	# this allows mutiple OR'd queries on the same table to use the
	# same instance of that table. Does not apply to ANDs 
	$mergemap = {} if !defined $mergemap;

	my @list = ( "OR" );
	foreach my $sub_op ( $self->ordered_ops )
	{
		push @list, $sub_op->get_query_tree( $session, $qdata, $mergemap );
	}

	return \@list;
}

sub process
{
	my( $self, $session, $i, $filter ) = @_;



	$i = 0 unless( defined $i );

#print STDERR "PROCESS: ".("  "x$i)."OR\n";
	my $set;
	foreach my $sub_op ( $self->ordered_ops )
	{
		my $r = $sub_op->process( $session, $i + 1);
		if( !defined $set )
		{
			$set = $r;
			next;
		}
		$set = EPrints::Search::Condition::_merge( $r , $set, 0 );
	}
#print STDERR "PROCESS: ".("  "x$i)."/OR [".join(",",@{$set})."]\n";
#
	return $set;
}


1;
