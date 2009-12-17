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

use EPrints::Search::Condition;

@ISA = qw( EPrints::Search::Condition );

use strict;

sub new
{
	my( $class, @params ) = @_;

	return bless { op=>"PASS" }, $class;
}

sub is_empty
{
	my( $self ) = @_;

	return 1;
}

sub joins
{
	EPrints->abort( "Can't create table joins for PASS condition" );
}

sub logic
{
	EPrints->abort( "Can't create SQL logic for PASS condition" );
}

1;
