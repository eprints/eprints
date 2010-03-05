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
use EPrints::Search::Condition::Regexp;
use EPrints::Search::Condition::SubQuery;
use EPrints::Search::Condition::AndSubQuery;
use EPrints::Search::Condition::OrSubQuery;

use Scalar::Util qw( refaddr );

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
	if( $op eq "grep" ) { return EPrints::Search::Condition::Grep->new( @params ); }
	if( $op eq "regexp" ) { return EPrints::Search::Condition::Regexp->new( @params ); }
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
	$op_desc.= " ... ".$self->table;
	return $op_desc;
}

sub extra_describe_bits
{
	my( $self ) = @_;

	return();
}

=item $field = $scond->field

Returns the field this search condition applies to.

Returns undef if this condition has no field.

=cut

sub field
{
	my( $self ) = @_;

	return $self->{field};
}

=item $dataset = $scond->dataset

Returns the dataset this search condition applies to.

Returns undef if this condition has no dataset requirement.

=cut

sub dataset
{
	my( $self ) = @_;

	return undef if( !defined $self->{field} );

	return $self->{field}->{dataset};
}

######################################################################
=pod

=item $sql_table = $scond->table

Returns the SQL table name this condition will work on.

Returns undef if this condition has no table requirement.

=cut
######################################################################

sub table
{
	my( $self ) = @_;

	return undef if( !defined $self->{field} );

	if( $self->{field}->get_property( "multiple" ) )
	{	
		return $self->{field}->{dataset}->get_sql_sub_table_name( $self->{field} );
	}	
	return $self->{field}->{dataset}->get_sql_table_name();
}

=item $bool = $scond->is_empty()

Returns true if this search condition is empty and should be ignored.

=cut

sub is_empty
{
	my( $self ) = @_;

	return 0;
}

######################################################################
=pod

=item $bool = $scond->item_matches( $dataobj )

DEPRECATED!

=cut
######################################################################

sub item_matches
{
	my( $self, $item ) = @_;

	my $scond = EPrints::Search::Condition::And->new(
		EPrints::Search::Condition::Comparison->new(
			"=",
			$item->get_dataset,
			$item->get_dataset->get_key_field,
			$item->get_id
		),
		$self );

	my $ids = $scond->process( session => $item->get_session, dataset => $item->get_dataset );

	return 1 if @$ids == 1;
}

=item @joins = $scond->joins( %opts )

Returns a list of joins that this condition requires.

Each join is a hash containing:

	table - table
	subquery - SQL sub-query
	alias - name to alias to
	type - "inner" or "left"
	key - column on alias to join against the main dataset

'table' is required and will only be joined once.

=cut

sub joins
{
	my( $self, %opts ) = @_;

	return ();
}

=item $logic = $scond->logic( %opts )

Returns the logic part of this condition.

=cut

sub logic
{
	my( $self, %opts ) = @_;

	return ();
}


=item $sql = $scond->sql( %opts )

Generates the SQL necessary to execute this condition tree.

=cut

sub sql
{
	my( $self, %opts ) = @_;

	my $session = $opts{session};
	my $db = $session->get_database;

	my $dataset = $opts{dataset};
	my $key_field = $dataset->get_key_field;

	my $order = delete $opts{order};
	my @orders = $self->_split_order_by( $session, $dataset, $order );

	my $key_alias = delete $opts{key_alias};

	my $groupby = delete $opts{groupby};

	my $ov_table = $dataset->get_ordervalues_table_name( $session->get_langid );

	my $sql = "";
	my @joins;

	my $groupby_table = "groupby_".refaddr( $self );

	if( !defined $groupby )
	{
		# SELECT dataset_main_table.key_field
		$sql .= "SELECT ".$db->quote_identifier( $dataset->get_sql_table_name, $key_field->get_sql_name );
		if( defined $key_alias )
		{
			$sql .= $db->sql_AS.$db->quote_identifier( $key_alias );
		}
	}
	elsif( !$groupby->get_property( "multiple" ) )
	{
		$groupby_table = $dataset->get_sql_table_name;
		# SELECT dataset_main_table.groupby, COUNT(DISTINCT dataset_main_table.key_field)
		$sql .= "SELECT ";
		$sql .= join ", ", map { $db->quote_identifier( $groupby_table, $_ ) } $groupby->get_sql_names;
		$sql .= ", COUNT(DISTINCT ".$db->quote_identifier( $dataset->get_sql_table_name, $key_field->get_sql_name ).")";
	}
	else
	{
		# SELECT groupby_table.groupby, COUNT(DISTINCT dataset_main_table.key_field)
		$sql .= "SELECT ";
		$sql .= join ", ", map { $db->quote_identifier( $groupby_table, $_ ) } $groupby->get_sql_names;
		$sql .= ", COUNT(DISTINCT ".$db->quote_identifier( $dataset->get_sql_table_name, $key_field->get_sql_name ).")";
		push @joins, {
			type => "inner",
			table => $dataset->get_sql_sub_table_name( $groupby ),
			alias => $groupby_table,
			key => $key_field->get_sql_name
		};
	}

	# FROM dataset_main_table
	$sql .= " FROM ".$db->quote_identifier( $dataset->get_sql_table_name );
	# LEFT JOIN dataset_ordervalues
	if( scalar @orders )
	{
		$sql .= " LEFT JOIN ".$db->quote_identifier( $ov_table );
		$sql .= " ON ".$db->quote_identifier( $dataset->get_sql_table_name, $key_field->get_sql_name )."=".$db->quote_identifier( $ov_table, $key_field->get_sql_name );
	}

	push @joins, $self->joins( %opts );

	my @tables;
	my @logic;
	my $i = 0;
	foreach my $join ( @joins )
	{
		# FROM ..., dataset_aux {alias}
		# WHERE dataset_main_table.key_field={alias}.join_key
		# or
		# FROM ..., join_table {ALIAS} INNER JOIN dataset_aux {alias} ON {ALIAS}.join_key={alias}.join_key
		# WHERE dataset_main_table.key_field={ALIAS}.join_key
		if( $join->{type} eq "inner" )
		{
			my $sql = "";
			$sql .= defined $join->{subquery} ? $join->{subquery} : $db->quote_identifier( $join->{table} );
			if( defined $join->{alias} )
			{
				$sql .= $db->sql_AS.$db->quote_identifier( $join->{alias} );
			}
			push @tables, $sql;
			if( defined $join->{logic} ) # overridden table join logic (used by subject ancestors)
			{
				push @logic, $join->{logic};
			}
			else
			{
				push @logic,
					$db->quote_identifier( $dataset->get_sql_table_name, $key_field->get_sql_name )."=".$db->quote_identifier( $join->{alias}, $join->{key} );
			}
		}
		# FROM ... , dataset_main_table {ALIAS} LEFT JOIN (subquery|table) {alias} ON dataset_main_table.key_field={alias}.join_key
		# WHERE dataset_main_table.key_field={ALIAS}.key_field
#		elsif( $join->{type} eq "left" )
#		{
#			my $main_alias = $i++ . "_" . $dataset->get_sql_table_name;
#			my $sql = "";
#			$sql .= $db->quote_identifier( $dataset->get_sql_table_name );
#			$sql .= " " . $db->quote_identifier( $main_alias );
#			$sql .= " LEFT JOIN ";
#			$sql .= defined $join->{subquery} ? $join->{subquery} : $db->quote_identifier( $join->{table} );
#			$sql .= " " . $db->quote_identifier( $join->{alias} );
#			$sql .= " ON " . $db->quote_identifier( $main_alias, $key_field->get_sql_name )."=".$db->quote_identifier( $join->{alias}, $join->{key} );
#			push @tables, $sql;
#			push @logic,
#				$db->quote_identifier( $dataset->get_sql_table_name, $key_field->get_sql_name )."=".$db->quote_identifier( $main_alias, $key_field->get_sql_name );
#		}
		else
		{
			EPrints::abort( "Unknown join type '$join->{type}' in table join construction" );
		}
	}

	$sql .= join("", map { ", $_" } @tables);

	push @logic, $self->logic( %opts );
	if( @logic )
	{
		$sql .= " WHERE ".join(" AND ", @logic);
	}

	# don't need to GROUP BY subqueries
	if( !defined $key_alias )
	{
		if( !defined $groupby )
		{
			$sql .= " GROUP BY ".$db->quote_identifier( $dataset->get_sql_table_name, $key_field->get_sql_name );
			if( scalar @orders )
			{
				foreach my $order ( @orders )
				{
					$sql .= ", ".$db->quote_identifier( $ov_table, $order->[0] );
				}
				$sql .= " ORDER BY ";
				$sql .= join(", ", map { $db->quote_identifier( $ov_table, $_->[0] ) . " " . $_->[1] } @orders );
			}
		}
		else
		{
			$sql .= " GROUP BY ";
			$sql .= join ", ", map { $db->quote_identifier( $groupby_table, $_ ) } $groupby->get_sql_names;
		}
	}

#print STDERR $self->describe;
#print STDERR "\nsql=$sql\n\n";

	return $sql;
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
	my( $self, %opts ) = @_;

	my $session = $opts{session};
	EPrints::abort "Requires session argument" if !defined $session;

	my $db = $opts{session}->get_database;

	my $dataset = $opts{dataset};
	EPrints::abort "Requires dataset argument" if !defined $dataset;

	my $cachemap = delete $opts{cachemap};
	my $limit = delete $opts{limit};

	my $sql = $self->sql( %opts );

	if( defined $cachemap )
	{
		my $key_field = $dataset->get_key_field;
		my $cache_table = $cachemap->get_sql_table_name;

#print STDERR "EXECUTING: $sql\n";
		$db->_cache_from_SELECT( $cachemap, $dataset, $sql );

		$sql = "SELECT ".$db->quote_identifier( $key_field->get_sql_name )." FROM ".$db->quote_identifier($cache_table)." ORDER BY ".$db->quote_identifier("pos");
	}

#print STDERR "EXECUTING: $sql\n";
	my $sth = $db->prepare_select( $sql, limit => $limit );
	$db->execute($sth, $sql);

	my @results;

	while(my $row = $sth->fetch)
	{
		push @results, $row->[0];
	}

	return \@results;
}

sub _split_order_by
{
	my( $self, $session, $dataset, $order ) = @_;

	return () unless defined $order;

	my $db = $session->get_database;

	my @orders;

	foreach my $fieldname ( split( "/", $order ) )
	{
		my $desc = 0;
		if( $fieldname =~ s/^-// ) { $desc = 1; }
		my $field = EPrints::Utils::field_from_config_string( $dataset, $fieldname );
		push @orders, [
				$field->get_sql_name,
				$desc ? "DESC" : "ASC"
			];
	}

	return @orders;
}

=item ($values, $counts) = $scond->process_groupby( field => $field, %opts )

B<Warning!> This method is experimental and subject to change.

Returns two array refs - the first is the list of unique values found in $field and the second the number of times each value was encountered.

=cut

sub process_groupby
{
	my( $self, %opts ) = @_;

	my $session = $opts{session};
	EPrints::abort "Requires session argument" if !defined $session;

	my $db = $opts{session}->get_database;

	my $dataset = $opts{dataset};
	EPrints::abort "Requires dataset argument" if !defined $dataset;

	my $groupby = delete $opts{field};
	if( $groupby->get_dataset->confid ne $dataset->confid )
	{
		EPrints::abort( "Can only only group-by on field in main dataset" );
	}

	delete $opts{order}; # doesn't make sense

	my $limit = delete $opts{limit};

	my $sql = $self->sql( %opts, groupby => $groupby );

#print STDERR "EXECUTING: $sql\n";
	my $sth = $db->prepare_select( $sql );
	$db->execute($sth, $sql);

	my( @values, @counts );

	while(my @row = $sth->fetchrow_array)
	{
		push @values, $groupby->value_from_sql_row( $session, \@row );
		push @counts, $row[0];
	}

	return( \@values, \@counts );
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
	my( $self, %opts ) = @_;

	return $self;
}

# return the keys to join two datasets together
sub join_keys
{
	my( $self, $source, $target ) = @_;

	my $left_key = $source->get_key_field->get_name;
	my $right_key = $target->get_key_field->get_name;

	if( $source->has_field( $right_key ) )
	{
		return( $right_key, $right_key );
	}
	elsif( $target->has_field( $left_key ) )
	{
		return( $left_key, $left_key );
	}
	else
	{
		EPrints::abort( "Can't create join path for: ".$source->confid." -> ".$target->confid );
	}
}

1;

######################################################################
=pod

=back

=cut

