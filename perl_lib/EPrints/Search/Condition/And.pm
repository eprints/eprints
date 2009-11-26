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

	return $self;
}

sub joins
{
	my( $self, %opts ) = @_;

	my $i = 0;
	my %seen;
	my @joins;
	foreach my $sub_op ( @{$self->{sub_ops}} )
	{
		foreach my $join ( $sub_op->joins( %opts, prefix => "and_".$i++."_" ) )
		{
			next if $seen{$join->{alias}};
			$seen{$join->{alias}} = 1;
			push @joins, $join;
		}
	}

	return @joins;
}

sub logic
{
	my( $self, %opts ) = @_;

	my $i = 0;
	return join(" AND ", map { $_->logic( %opts, prefix => "and_".$i++."_" ) } @{$self->{sub_ops}});
}

1;
