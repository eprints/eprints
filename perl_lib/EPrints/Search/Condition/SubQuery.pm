######################################################################
#
# EPrints::Search::Condition::SubQuery
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

B<EPrints::Search::Condition::SubQuery> - SubQuery

=head1 DESCRIPTION

SubQuery is used internally by the search optimisation to make OR queries on the same table more efficient.

=cut

package EPrints::Search::Condition::SubQuery;

use EPrints::Search::Condition;
use Scalar::Util qw( refaddr );

@ISA = qw( EPrints::Search::Condition );

use strict;

sub new
{
	my( $class, @params ) = @_;

	my $self = bless {
			op => "SubQuery",
			dataset => shift(@params),
			sub_ops => \@params
		}, $class;

	return $self;
}

sub joins
{
	my( $self, %opts ) = @_;

	return $self->{sub_ops}->[0]->joins( %opts );
}

sub logic
{
	my( $self, %opts ) = @_;

	return "(" . join(" OR ", map { $_->logic( %opts ) } @{$self->{sub_ops}} ) . ")";
}

sub alias
{
	my( $self ) = @_;

	my $alias = lc(ref($self));
	$alias =~ s/^.*:://;
	$alias .= "_".refaddr($self);

	return $alias;
}

sub key_alias
{
	my( $self, %opts ) = @_;

	my $dataset = $opts{dataset};

	return $dataset->get_key_field->get_sql_name . "_" . refaddr($self);
}

1;
