######################################################################
#
# EPrints::Search::Condition::True
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

B<EPrints::Search::Condition::True> - "True" search condition

=head1 DESCRIPTION

Matches all items.

=cut

package EPrints::Search::Condition::True;

use EPrints::Search::Condition;

@ISA = qw( EPrints::Search::Condition );

use strict;

sub new
{
	my( $class ) = @_;

	return bless { op=>"TRUE" }, $class;
}

sub logic
{
	return "1=1";
}

1;
