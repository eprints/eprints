######################################################################
#
# EPrints::Search::Condition
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

B<EPrints::Search::Condition> - Atomic search condition.

=head1 DESCRIPTION

Represents a simple atomic search condition like 
abstract contains "fish" or date is bigger than 2000.

Can also represent a "AND" or "OR"'d list of sub-conditions, so
forming a tree-like data-structure.

Search conditions can be used either to create search results (as
a list of id's), or to test if a single object matches the 
condition.

This module should usually not be used directly. It is used
internally by EPrints::Search.

=over 4

=cut

######################################################################
#
# INSTANCE VARIABLES:
#
#  $self->{op}
#     The ID of the simple search operation.
#
#  $self->{dataset}
#     The EPrints::Dataset we are searching.
#
#  $self->{field}
#     The EPrints::MetaField which this condition applies to.
#
#  $self->{params}
#     Array reference to Parameters to the op, varies depending on
#     the op.
#
#  $self->{subops}
#     Array reference containing sub-search conditions used by AND
#     and or conditions.
#
######################################################################

package EPrints::Search::Condition;

use strict;

use EPrints::Search::Condition::True;
use EPrints::Search::Condition::False;
use EPrints::Search::Condition::Pass;
use EPrints::Search::Condition::And;
use EPrints::Search::Condition::Or;
use EPrints::Search::Condition::Index;
use EPrints::Search::Condition::IndexStart;
use EPrints::Search::Condition::Grep;
use EPrints::Search::Condition::NameMatch;
use EPrints::Search::Condition::InSubject;
use EPrints::Search::Condition::IsNull;
use EPrints::Search::Condition::Comparison;

# current conditional operators:

$EPrints::Search::Condition::TABLEALIAS = "d41d8cd98f00b204e9800998ecf8427e";


######################################################################
=pod

=item $scond = EPrints::Search::Condition->new( $op, @params );

Create a new search condition object with the given operation and
parameters.

=cut
######################################################################

sub new
{
	my( $class, $op, @params ) = @_;

	if( $op eq "TRUE" ) { return EPrints::Search::Condition::True->new( @params ); }
	if( $op eq "FALSE" ) { return EPrints::Search::Condition::False->new( @params ); }
	if( $op eq "PASS" ) { return EPrints::Search::Condition::Pass->new( @params ); }
	if( $op eq "AND" ) { return EPrints::Search::Condition::And->new( @params ); }
	if( $op eq "OR" ) { return EPrints::Search::Condition::Or->new( @params ); }
	if( $op eq "index" ) { return EPrints::Search::Condition::Index->new( @params ); }
	if( $op eq "index_start" ) { return EPrints::Search::Condition::IndexStart->new( @params ); }
	if( $op eq "name_match" ) { return EPrints::Search::Condition::NameMatch->new( @params ); }
	if( $op eq "in_subject" ) { return EPrints::Search::Condition::InSubject->new( @params ); }
	if( $op eq "is_null" ) { return EPrints::Search::Condition::IsNull->new( @params ); }
	if ( $op =~ m/^(=|<=|>=|<|>)$/ )
	{
		return EPrints::Search::Condition::Comparison->new( $op, @params );
	}

	EPrints::abort( "Unknown Search::Condition '$op'" );
}

######################################################################
=pod

=item $desc = $scond->describe

Return a text description of the structure of this search condition
tree. Used for debugging.

=cut
######################################################################

sub describe
{
	my( $self, $indent ) = @_;
	
	$indent = 0 unless( defined $indent );

	my $ind = "\t"x$indent;
	++$indent;

	if( defined $self->{sub_ops} )
	{
		my @r = ();
		foreach( @{$self->{sub_ops}} )
		{
			push @r, $_->describe( $indent );
		}
		return $ind.$self->{op}."(\n".join(",\n",@r)."\n".$ind.")";
	}

	if( !defined $self->{field} )
	{
		return $ind.$self->{op};
	}	

	my @o = ();
	if( defined $self->{field} )
	{
		push @o, '$'.$self->{dataset}->id.".".$self->{field}->get_name;
	}	

	push @o, $self->extra_describe_bits;

	if( defined $self->{params} )
	{
		foreach( @{$self->{params}} )
		{
			push @o, '"'.$_.'"';
		}
	}	
	my $op_desc = $ind.$self->{op}."(".join( ",", @o ).")";
	$op_desc.= " ... ".$self->get_table;
	return $op_desc;
}

sub extra_describe_bits
{
	my( $self ) = @_;

	return();
}

######################################################################
=pod

=item $sql_table = $scond->get_table

Return the name of the actual SQL table which this condition is
concerned with.

=cut
######################################################################

sub get_table
{
	my( $self ) = @_;

	return undef if( !defined $self->{field} );

	if( $self->{field}->get_property( "multiple" ) )
	{	
		return $self->{dataset}->get_sql_sub_table_name( $self->{field} );
	}	
	return $self->{dataset}->get_sql_table_name();
}

sub get_tables
{
	my( $self, $session ) = @_;

	my $field = $self->{field};
	my $dataset = $self->{dataset};

	my $jp = $field->get_property( "join_path" );
	my @f = ();
	if( $jp )
	{
		foreach my $join ( @{$jp} )
		{
			my( $j_field, $j_dataset ) = @{$join};
			my $join_data = {};
			if( $j_field->is_type( "subobject" ) )
			{
				my $right_ds = $session->get_repository->get_dataset( 
					$j_field->get_property('datasetid') );
				$join_data->{table} = $right_ds->get_sql_table_name();
				$join_data->{left} = $j_dataset->get_key_field->get_name();
				$join_data->{right} = $right_ds->get_key_field->get_name();
			}
			else
			{
				# itemid
				if( $j_field->get_property( "multiple" ) )
				{
					$join_data->{table} = $j_dataset->get_sql_sub_table_name( $j_field );
					$join_data->{left} = $j_dataset->get_key_field->get_name();
					$join_data->{right} = $j_field->get_name();
				}
				else
				{
					$join_data->{table} = $j_dataset->get_sql_table_name();
					$join_data->{left} = $j_dataset->get_key_field->get_name();
					$join_data->{right} = $j_field->get_name();
				}
			}
			push @f, $join_data;
		}
	}

	return \@f;	
}


######################################################################
=pod

=item $bool = $scond->item_matches( $dataobj )


=cut
######################################################################

sub item_matches
{
	my( $self, $item ) = @_;

	EPrints::abort( "item_matches needs to be subclassed" );
}


# return a reference to an array of ID's
# or ["ALL"] to represent the entire set.

######################################################################
=pod

=item $ids = $scond->process( $session, [$indent], [$filter] );

Return a reference to an array containing the ID's of items in
the database which match this condition.

If the search condition matches the whole dataset then it returns
["ALL"] rather than a huge list of ID's.

$indent is only used for debugging code. 

$filter is only used in ops of type "grep". It is a reference to
an array of ids of items to be greped, so that the grep does not
need to be applied to all values in the database.

=cut
######################################################################

sub process
{
	my( $self, $session, $i, $filter ) = @_;

	EPrints::abort( "process needs to be subclassed" );
}

sub run_tables
{
	my( $self, $session, $tables ) = @_;

	my $db = $session->get_database;

	my @opt_tables;
	while( scalar @{$tables} )
	{
		my $head = shift @$tables;
		while( scalar @$tables && $head->{right} eq $tables->[0]->{left} && $head->{table} eq $tables->[0]->{table} )
		{
			my $head2 = shift @$tables;
			$head->{right} = $head2->{right};
			if( defined $head2->{where} )
			{
				if( defined $head->{where} )
				{
					$head->{where} = "(".$head->{where}.") AND (".$head2->{where}.")";
				}
				else
				{
					$head->{where} = $head2->{where};
				}
			}
		}
		push @opt_tables, $head;
	}

	my @sql_wheres = ();
	my @sql_tables = ();
	for( my $tn=0; $tn<scalar @opt_tables; $tn++ )
	{
		my $tabinfo = $opt_tables[$tn];
		push @sql_tables, $db->quote_identifier($tabinfo->{table})." ".$db->quote_identifier("T$tn");
		if( defined $tabinfo->{right} )
		{
			push @sql_wheres, $db->quote_identifier("T$tn", $tabinfo->{right})."=".$db->quote_identifier("T".($tn+1), $opt_tables[$tn+1]->{left});
		}
		if( defined $tabinfo->{where} )
		{
			my $where = $tabinfo->{where};
			$where =~ s/$EPrints::Search::Condition::TABLEALIAS/T$tn/g;
			push @sql_wheres, $where;
		}
	}

	my $sql = "SELECT DISTINCT ".$db->quote_identifier("T0",$opt_tables[0]->{left})." FROM ".join( ", ", @sql_tables )." WHERE (".join(") AND (", @sql_wheres ).")";
#print "$sql\n";
	my $results = [];
	my $sth = $session->get_database->prepare( $sql );
	$session->get_database->execute( $sth, $sql );
	while( my @info = $sth->fetchrow_array ) 
	{
		push @{$results}, $info[0];
	}
	$sth->finish;

	return( $results );
}

######################################################################
=pod

=item $opt_scond = $scond->optimise

Rearrange this condition tree so that it is more optimised.

For example an "OR" where one sub op is "TRUE" can be optimised to
just be "TRUE" itself.

Returns the now optimised search condition tree. Not always the same
top level object.

=cut
######################################################################

sub optimise
{
	my( $self, $internal ) = @_;

	return $self;
}


# "ALL"
sub _merge
{
	my( $a, $b, $and ) = @_;

	$a = [] unless( defined $a );
	$b = [] unless( defined $b );
	my $a_all = ( defined $a->[0] && $a->[0] eq "ALL" );
	my $b_all = ( defined $b->[0] && $b->[0] eq "ALL" );
	if( $and )
	{
		return $b if( $a_all );
		return $a if( $b_all );
	}
	elsif( $a_all || $b_all )
	{
		# anything OR'd with "ALL" is "ALL"
		return [ "ALL" ];
	}

	my @c;
	if ($and) {
		my (%MARK);
		grep($MARK{$_}++,@{$a});
		@c = grep($MARK{$_},@{$b});
	} else {
		my (%MARK);
		foreach(@{$a}, @{$b}) {
			$MARK{$_}++;
		}
		@c = keys %MARK;
	}

	return \@c;
}



1;

######################################################################
=pod

=back

=cut

