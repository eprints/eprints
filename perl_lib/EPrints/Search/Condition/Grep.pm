######################################################################
#
# EPrints::Search::Condition::Grep
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

B<EPrints::Search::Condition::Grep> - "Grep" search condition

=head1 DESCRIPTION

Filter using a grep table

=cut

package EPrints::Search::Condition::Grep;

use EPrints::Search::Condition;

BEGIN
{
	our @ISA = qw( EPrints::Search::Condition );
}

use strict;

sub new
{
	my( $class, @params ) = @_;

	my $self = {};
	$self->{op} = "grep";
	$self->{dataset} = shift @params;
	$self->{field} = shift @params;
	$self->{params} = \@params;

	return bless $self, $class;
}


sub item_matches
{
	my( $self, $item ) = @_;

 	my $keyfield = $self->{dataset}->get_key_field();
	my $sql_col = $self->{field}->get_sql_name;

	my( $codes, $grepcodes, $badwords ) =
		$self->{field}->get_index_codes(
			$item->get_session,
			$item->get_value( $self->{field}->get_name ) );

	my @re = ();
	foreach( @{$self->{params}} )
	{
		my $r = $_;
		$r =~ s/([^a-z0-9%?])/\\$1/gi;
		$r =~ s/\%/.*/g;
		$r =~ s/\?/./g;
		push @re, $r;
	}
		
	my $regexp = '^('.join( '|', @re ).')$';

	foreach my $grepcode ( @{$grepcodes} )
	{
		return( 1 ) if( $grepcode =~ m/$regexp/ );
	}

	return( 0 );
}

sub get_op_val
{
	return 4;
}

sub get_query_joins
{
	my( $self, $joins, %opts ) = @_;

	my $field = $self->{field};
	my $dataset = $field->{dataset};

	$joins->{$dataset->confid} ||= { dataset => $dataset };
	$joins->{$dataset->confid}->{'multiple'} ||= [];

	my $alias = $dataset->get_sql_grep_table_name( $field );
	push @{$joins->{$dataset->confid}->{'multiple'}}, $self->{join} = {
		table => $alias,
		alias => $alias,
		key => $dataset->get_key_field->get_sql_name,
	};
}

sub get_query_logic
{
	my( $self, %opts ) = @_;

	my $db = $opts{session}->get_database;
	my $field = $self->{field};
	my $dataset = $field->{dataset};

	my $q_table = $db->quote_identifier($self->{join}->{alias});
	my $q_grepstring = $db->quote_identifier("grepstring");
	my $q_fieldname = $db->quote_identifier("fieldname");
	my $q_fieldvalue = $db->quote_value($field->get_sql_name);

	my @logic;
	foreach my $cond (@{$self->{params}})
	{
		# escape $cond value in any way?
		push @logic, "$q_table.$q_grepstring LIKE '$cond'";
	}

	return "(($q_table.$q_fieldname = $q_fieldvalue) AND (".join( " OR ", @logic )."))";
}

1;
