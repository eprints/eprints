######################################################################
#
# EPrints::MetaField::Id;
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

B<EPrints::MetaField::Id> - no description

=head1 DESCRIPTION

not done

=over 4

=cut

package EPrints::MetaField::Id;

use strict;
use warnings;

BEGIN
{
	our( @ISA );

	@ISA = qw( EPrints::MetaField );
}

use EPrints::MetaField;


sub get_search_conditions_not_ex
{
	my( $self, $handle, $dataset, $search_value, $match, $merge,
	$search_mode ) = @_;

	return EPrints::Search::Condition->new(
		'=',
		$dataset,
		$self,
		$search_value );
}



######################################################################
1;
