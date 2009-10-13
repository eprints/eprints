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

BEGIN
{
	our @ISA = qw( EPrints::Search::Condition::Comparison );
}

use strict;

sub new
{
	my( $class, @params ) = @_;

	my $self = {};
	$self->{op} = "name_match";
	$self->{dataset} = shift @params;
	$self->{field} = shift @params;
	$self->{params} = \@params;

	return bless $self, $class;
}


sub extra_describe_bits
{
	my( $self ) = @_;

	return '"'.$self->{params}->[0]->{family}.'"', 
		'"'.$self->{params}->[0]->{given}.'"';
}


sub item_matches
{
	my( $self, $item ) = @_;

 	my $keyfield = $self->{dataset}->get_key_field();
	my $sql_col = $self->{field}->get_sql_name;

	print STDERR "\n---name_match comparisson not done yet...\n";

	return 1;
}

sub get_op_val
{
	return 4;
}

1;
