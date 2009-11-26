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

A SQL sub-query, which is required to efficiently perform ORs over multiple tables.

=cut

package EPrints::Search::Condition::SubQuery;

use EPrints::Search::Condition::Or;
use Scalar::Util qw( refaddr );

@ISA = qw( EPrints::Search::Condition::Or );

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

sub _sql
{
	my( $self, %opts ) = @_;

	my $db = $opts{session}->get_database;

	my $dataset = $opts{dataset};
	my $inner_dataset = $self->{dataset};

	my $key_alias = delete $opts{key_alias};

	my $sql = "";

	my $sub_op = $self->{sub_ops}->[0];

	my( $join ) = $sub_op->joins( %opts );

	$sql .= "SELECT ".$db->quote_identifier( $join->{key} )." ".$db->quote_identifier( $key_alias );

	$sql .= " FROM ".(defined( $join->{subquery} ) ? $join->{subquery} : $db->quote_identifier( $join->{table} ));

	if( defined $join->{alias} )
	{
		$sql .= " ".$db->quote_identifier( $join->{alias} );
	}

	my @logic = map { $_->logic( %opts ) } @{$self->{sub_ops}};
	if( @logic )
	{
		$sql .= " WHERE ".join(" OR ", @logic);
	}

	return $sql;
}

sub joins
{
	my( $self, %opts ) = @_;

	my $db = $opts{session}->get_database;
	my $dataset = $opts{dataset};
	my $key_alias = $self->key_alias( %opts );

	my $sql = "(" . $self->_sql( %opts, key_alias => $key_alias ) . ")";

	return {
		type => "left",
		table => $self->alias,
		subquery => $sql,
		alias => $self->alias,
		key => $key_alias,
	};
}

sub logic
{
	my( $self, %opts ) = @_;

	my $db = $opts{session}->get_database;

	my $key_alias = $self->key_alias( %opts );

	return $db->quote_identifier( $self->alias, $key_alias )." IS NOT NULL";
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
