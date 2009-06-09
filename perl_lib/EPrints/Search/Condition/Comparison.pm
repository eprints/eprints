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

B<EPrints::Search::Condition::Comparison> - "Comparison" search condition

=head1 DESCRIPTION

Matches items which are < > = <= or => to a value.

=cut

package EPrints::Search::Condition::Comparison;

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
	$self->{op} = shift @params;
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
		
	my @values = $self->{field}->list_values( 
		$item->get_value( $self->{field}->get_name ) );
	my $op = $self->{op};
	my $right = $self->{params}->[0];
	if( $self->{field}->is_type( "year","int") )
	{
		foreach my $value ( @values )
		{
			return 1 if( $op eq "="  && $value == $right );
			return 1 if( $op eq ">"  && $value >  $right );
			return 1 if( $op eq "<"  && $value <  $right );
			return 1 if( $op eq ">=" && $value >= $right );
			return 1 if( $op eq "<=" && $value <= $right );
		}
	}
	else
	{
		foreach my $value ( @values )
		{
			return 1 if( $op eq "="  && $value eq $right );
			return 1 if( $op eq ">"  && $value gt $right );
			return 1 if( $op eq "<"  && $value lt $right );
			return 1 if( $op eq ">=" && $value ge $right );
			return 1 if( $op eq "<=" && $value le $right );
		}
	}

	return( 0 );
}

sub get_datetime_where_clause
{
	my( $self, $session ) = @_;
	
	my $database = $session->get_database;
	my $sql_col = $self->{field}->get_sql_name;

	my( $cmp, $eq ) = @{ { 
		'>=', [ '>', 1 ],
		'<=', [ '<', 1 ],
		'>', [ '>', 0 ],
		'<', [ '<', 0 ],
		'=', [ undef, 1 ] }->{$self->{op}} };
	my $timemap = [ 'year','month','day','hour','minute','second' ];

	my @parts = split( /[-: TZ]/, $self->{params}->[0] );
	my $nparts = scalar @parts;
	if( $self->{field}->is_type( "date" ) && $nparts > 3 )
	{
		$nparts = 3;
	}

	my @or = ();

	if( defined $cmp )
	{
		for( my $i=0;$i<$nparts;++$i )
		{
			my @and = ();
			for( my $j=0;$j<=$i;++$j )
			{	
				my $o = "=";
				if( $j==$i ) { $o = $cmp; }
				push @and, $database->quote_identifier($EPrints::Search::Condition::TABLEALIAS,$sql_col."_".$timemap->[$j])." ".$o." ".$database->quote_value( $parts[$j] ); 
			}
			push @or, "( ".join( " AND ", @and )." )";
		}
	}

	if( $eq )
	{
		my @and = ();
		for( my $i=0;$i<$nparts;++$i )
		{
			push @and, $database->quote_identifier($EPrints::Search::Condition::TABLEALIAS,$sql_col."_".$timemap->[$i])." = ".$database->quote_value( $parts[$i] ); 
		}
		push @or, "( ".join( " AND ", @and )." )";
	}

	return "(".join( " OR ", @or ).")";
}

sub get_tables
{
	my( $self, $session ) = @_;

	my $database = $session->get_database;
	my $tables = $self->SUPER::get_tables( $session );
	my $keyfield = $self->{dataset}->get_key_field();
	my $sql_col = $self->{field}->get_sql_name;

	my $where;
	if( $self->{field}->is_type( "date", "time" ) )
	{
		$where = $self->get_datetime_where_clause( $session );
	}
	elsif( $self->{field}->is_type( "pagerange","int","year" ) )
	{
		$where = $database->quote_identifier($EPrints::Search::Condition::TABLEALIAS,$sql_col)." ".$self->{op}." ".EPrints::Database::prep_int( $self->{params}->[0] );
	}
	else
	{
		$where = $database->quote_identifier($EPrints::Search::Condition::TABLEALIAS,$sql_col)." ".$self->{op}." ".$database->quote_value( $self->{params}->[0] );
	}

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
	my( $self ) = @_;

	return 2 if( $self->{op} eq "=" );

	return 4;
}

1;
