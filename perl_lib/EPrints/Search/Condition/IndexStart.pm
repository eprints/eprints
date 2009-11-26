######################################################################
#
# EPrints::Search::Condition::IndexStart
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

B<EPrints::Search::Condition::IndexStart> - "IndexStart" search condition

=head1 DESCRIPTION

Matches items which are have a indexcode with the value as a prefix.

eg. Smi matches Smith.

=cut

package EPrints::Search::Condition::IndexStart;

use EPrints::Search::Condition::Index;

@ISA = qw( EPrints::Search::Condition::Index );

use strict;

sub new
{
	my( $class, @params ) = @_;

	my $self = {};
	$self->{op} = "index_start";
	$self->{dataset} = shift @params;
	$self->{field} = shift @params;
	$self->{params} = \@params;

	return bless $self, $class;
}

sub _item_matches
{
	my( $self, $item ) = @_;

	my( $codes, $grepcodes, $badwords ) =
		$self->{field}->get_index_codes(
			$item->get_session,
			$item->get_value( $self->{field}->get_name ) );

	my $p = $self->{params}->[0];
	foreach my $code ( @{$codes} )
	{
		return( 1 ) if( substr( $code, 0, length $p ) eq $p );
	}

	return( 0 );
}

sub get_op_val
{
	return 1;
}

sub get_query_logic
{
	my( $self, %opts ) = @_;

	my $db = $opts{session}->get_database;
	my $field = $self->{field};
	my $dataset = $field->{dataset};

	my $q_table = $db->quote_identifier($self->{join}->{alias});
	my $q_fieldname = $db->quote_identifier("field");
	my $q_fieldvalue = $db->quote_value($field->get_sql_name);
	my $q_word = $db->quote_identifier("word");
	my $q_value = EPrints::Database::prep_like_value( $self->{params}->[0] );

	return "($q_table.$q_fieldname = $q_fieldvalue AND $q_table.$q_word LIKE '$q_value\%')";
}

sub logic
{
	my( $self, %opts ) = @_;

	my $prefix = $opts{prefix};
	$prefix = "" if !defined $prefix;

	my $db = $opts{session}->get_database;
	my $table = $prefix . $self->table;
	my $sql_name = $self->{field}->get_sql_name;

	return sprintf( "%s=%s AND %s LIKE '%s%%'",
		$db->quote_identifier( $table, "field" ),
		$db->quote_value( $sql_name ),
		$db->quote_identifier( $table, "word" ),
		EPrints::Database::prep_like_value( $self->{params}->[0] ) );
}

1;
