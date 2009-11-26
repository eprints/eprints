######################################################################
#
# EPrints::Search::Condition::NameMatch
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

B<EPrints::Search::Condition::NameMatch> - "NameMatch" search condition

=head1 DESCRIPTION

Matches items with a matching name.

=cut

package EPrints::Search::Condition::NameMatch;

use EPrints::Search::Condition::Comparison;

@ISA = qw( EPrints::Search::Condition::Comparison );

use strict;

sub new
{
	my( $class, @params ) = @_;

	return $class->SUPER::new( "=", @params );
}

sub extra_describe_bits
{
	my( $self ) = @_;

	return '"'.$self->{params}->[0]->{family}.'"', 
		'"'.$self->{params}->[0]->{given}.'"';
}

1;
