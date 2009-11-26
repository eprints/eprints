######################################################################
#
# EPrints::Search::Condition::Comparison
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

B<EPrints::Search::Condition::Regexp> - "Regexp" search condition

=head1 DESCRIPTION

Matches items which match a regexp.

=cut

package EPrints::Search::Condition::Regexp;

use EPrints::Search::Condition::Comparison;

@ISA = qw( EPrints::Search::Condition::Comparison );

use strict;

sub new
{
	my( $class, @params ) = @_;

	my $self = {};
	$self->{dataset} = shift @params;
	$self->{field} = shift @params;
	$self->{params} = \@params;

	return bless $self, $class;
}

sub _item_matches
{
	my( $self, $item ) = @_;

	# TODO

	return( 0 );
}

sub get_query_logic
{
	my( $self, %opts ) = @_;

	my $db = $opts{session}->get_database;
	my $field = $self->{field};
	my $table = $self->{join}->{alias};

	# "REGEXP ($q_table.$q_name, $q_value)"
	return $db->prepare_regexp(
		$db->quote_identifier( $table, $field->get_sql_name ),
		$db->quote_value( $self->{params}->[0] ) );
}

sub logic
{
	my( $self, %opts ) = @_;

	my $prefix = $opts{prefix};
	$prefix = "" if !defined $prefix;
	if( !$self->{field}->get_property( "multiple" ) )
	{
		$prefix = "";
	}

	my $db = $opts{session}->get_database;
	my $table = $prefix . $self->table;
	my $sql_name = $self->{field}->get_sql_name;

	# "REGEXP ($q_table.$q_name, $q_value)"
	return $db->prepare_regexp(
		$db->quote_identifier( $table, $sql_name ),
		$db->quote_value( $self->{params}->[0] ) );
}

1;
