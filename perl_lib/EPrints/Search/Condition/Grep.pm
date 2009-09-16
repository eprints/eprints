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

sub get_tables
{
	my( $self, $session ) = @_;

	my $tables = $self->SUPER::get_tables( $session );
	my $database = $session->get_database;

	my $sql_col = $self->{field}->get_sql_name;
	my @ors = ();
	foreach my $cond (@{$self->{params}})
	{
		# not prepping like values...
		push @ors, $database->quote_identifier($EPrints::Search::Condition::TABLEALIAS,"grepstring")." LIKE '$cond'";
	}
	my $where = "( ".$database->quote_identifier($EPrints::Search::Condition::TABLEALIAS,"fieldname")." = '$sql_col' AND ( ".join( " OR ", @ors )." ))";

	push @{$tables}, {
		left => $self->{field}->get_dataset->get_key_field->get_name, 
		where => $where,
		table => $self->{dataset}->get_sql_grep_table_name,
	};

	return $tables;
}

sub process
{
	my( $self, $session, $i, $filter ) = @_;

	$i = 0 unless( defined $i );
	my $database = $session->get_database;
	my $tables = $self->SUPER::get_tables( $session );
	my $keyfield = $self->{dataset}->get_key_field();
	my $sql_col = $self->{field}->get_sql_name;

	if( !defined $filter )
	{
		print STDERR "WARNING: grep without filter! This is very inefficient.\n";	
		# cjg better logging?
	}

	my $where = "( ".$database->quote_identifier($EPrints::Search::Condition::TABLEALIAS,"fieldname")." = '$sql_col' AND (";
	my $first = 1;
	foreach my $cond (@{$self->{params}})
	{
		$where.=" OR " unless( $first );
		$first = 0;
		# not prepping like values...
		$where .= $database->quote_identifier($EPrints::Search::Condition::TABLEALIAS,"grepstring")." LIKE '$cond'";
	}
	$where.="))";

	my $gtable = $self->{dataset}->get_sql_grep_table_name;
	my $SSIZE = 50;
	my $total = scalar @{$filter};
	my $kfn = $database->quote_identifier($EPrints::Search::Condition::TABLEALIAS,$keyfield->get_sql_name); # key field name and table
	my $r = [];
	for( my $i = 0; $i<$total; $i+=$SSIZE )
	{
		my $max = $i+$SSIZE;
		$max = $total-1 if( $max > $total - 1 );
		my @fset = @{$filter}[$i..$max];

		push @{$tables}, {
			left => $self->{field}->get_dataset->get_key_field->get_name, 
			where => '('.$where.' AND ('.$kfn.'='.join(' OR '.$kfn.'=', @fset ).' ))',
			table => $gtable,
		};
		my $set = $self->run_tables( $session, $tables );
		$r = EPrints::Search::Condition::_merge( $r , $set, 0 );
	}

	return $r;
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

	$self->{alias} = $dataset->get_sql_grep_table_name( $field );
	push @{$joins->{$dataset->confid}->{'multiple'}}, {
		table => $self->{alias},
		alias => $self->{alias},
		key => $dataset->get_key_field->get_sql_name,
	};
}

sub get_query_logic
{
	my( $self, %opts ) = @_;

	my $db = $opts{session}->get_database;
	my $field = $self->{field};
	my $dataset = $field->{dataset};

	my $q_table = $db->quote_identifier($self->{alias});
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
