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

sub get_tables
{
	my( $self, $handle ) = @_;

	my $database = $handle->get_database;
	my $tables = $self->SUPER::get_tables( $handle );
	my $keyfield = $self->{dataset}->get_key_field();
	my $sql_col = $self->{field}->get_sql_name;

	my $where = "(".join(") AND (", map {
		$database->quote_identifier($EPrints::Search::Condition::TABLEALIAS,"$sql_col\_$_")."=".$database->quote_value($self->{params}->[0]->{$_})
	} qw( given family )).")";
	push @{$tables}, {
		left => $self->{field}->get_dataset->get_key_field->get_name, 
		where => $where,
		table => $self->{field}->get_property( "multiple" ) 
			? $self->{field}->get_dataset->get_sql_sub_table_name( $self->{field} ) 
			: $self->{field}->get_dataset->get_sql_table_name() 
	};

	return $tables;
}

sub get_op_val
{
	return 4;
}

1;
