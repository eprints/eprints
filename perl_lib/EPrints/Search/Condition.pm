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
			$sql .= " ".$db->quote_identifier( $key_alias );
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
		push @logic, $join->{logic} if defined $join->{logic};

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
				$sql .= " ".$db->quote_identifier( $join->{alias} );
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
		elsif( $join->{type} eq "left" )
		{
			my $main_alias = $i++ . "_" . $dataset->get_sql_table_name;
			my $sql = "";
			$sql .= $db->quote_identifier( $dataset->get_sql_table_name );
			$sql .= " " . $db->quote_identifier( $main_alias );
			$sql .= " LEFT JOIN ";
			$sql .= defined $join->{subquery} ? $join->{subquery} : $db->quote_identifier( $join->{table} );
			$sql .= " " . $db->quote_identifier( $join->{alias} );
			$sql .= " ON " . $db->quote_identifier( $main_alias, $key_field->get_sql_name )."=".$db->quote_identifier( $join->{alias}, $join->{key} );
			push @tables, $sql;
			push @logic,
				$db->quote_identifier( $dataset->get_sql_table_name, $key_field->get_sql_name )."=".$db->quote_identifier( $main_alias, $key_field->get_sql_name );
		}
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

		my $cache_table = $db->begin_cache_table( $cachemap, $key_field );
		$sql = "INSERT INTO ".$db->quote_identifier($cache_table)." (".$db->quote_identifier( $key_field->get_sql_name ).") ".$sql;
#print STDERR "EXECUTING: $sql\n";
		$db->do($sql);
		$db->finish_cache_table( $cachemap );
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

# TDB: This code is very complex and probably needs to be restructured. But it
# does make subclasses of Condition fairly simple.
sub _v3_process
{
	my( $self, %opts ) = @_;

	my $session = $opts{session};
	my $db = $opts{session}->get_database;

	my $dataset = $opts{dataset};

	my $cachemap = $opts{cachemap};

	my $table = $dataset->get_sql_table_name;
	my $q_table = $db->quote_identifier( $table );

	my $key_field_name = $dataset->get_key_field->get_sql_name;
	my $q_key_field_name = $db->quote_identifier( $key_field_name );

	# SELECT matching ids from the "main" dataset table's key field
	my $sql = "SELECT ".$db->quote_identifier($table,$key_field_name);

	# calculate the tables we need (with appropriate joins)
	my @joins;

	# work out the order value names
	my @orders = $self->_split_order_by( $session, $dataset, $opts{order} );

	# "main" LEFT JOIN "ordervalues"
	if( scalar @orders )
	{
		my $ov_table = $dataset->get_ordervalues_table_name( $session->get_langid );
		push @joins, _sql_left_join($db,
			$table,
			$key_field_name,
			[$ov_table, "OV"],
			$key_field_name );
	}
	# "main"
	else
	{
		push @joins, $db->quote_identifier( $table );
	}

	my $joins = {};
	# populate $joins with all the required tables
	$self->get_query_joins( $joins, %opts );

	my $idx = 0;
	my @join_logic;
	foreach my $datasetid (keys %$joins)
	{
		$joins->{$datasetid}->{'multiple'} ||= [];
		my $join_table = $table;
		my $join_key = $key_field_name;
		# join to the non-main dataset
		if( $datasetid ne $dataset->confid )
		{
			# join to the main dataset by aliasing the main dataset and then
			# doing a LEFT JOIN to the new dataset
			my $alias = ++$idx . "_" . $table;
			my $join_dataset = $joins->{$datasetid}->{dataset};
			my $table = $join_dataset->get_sql_table_name;
			my $key = $join_dataset->get_key_field->get_sql_name;
			my $left_key;
			my $right_key;
# TODO: this patches over the missing join_path support but isn't the solution
				# this dataset is child of main dataset
				if( $join_dataset->has_field( $key_field_name ) )
				{
					$left_key = $right_key = $key_field_name;
				}
				# main dataset is a child of this dataset
				elsif( $dataset->has_field( $join_dataset->get_key_field->get_sql_name ) )
				{
					$left_key = $right_key = $join_dataset->get_key_field->get_sql_name;
				}
				else
				{
					EPrints::abort( "Unknown join between datasets ".$dataset->confid." and ".$join_dataset->confid );
				}
			push @joins, _sql_left_join($db,
				[ $join_table, $alias ],
				$left_key,
				$table,
				$right_key ); # TODO: per-dataset join-path
			# assert the INNER JOIN between the alias and main dataset
			push @join_logic, sprintf("%s.%s=%s.%s",
				$db->quote_identifier($join_table),
				$db->quote_identifier($join_key),
				$db->quote_identifier($alias),
				$db->quote_identifier($join_key));
			# any fields will need to join to the new dataset
			$join_table = $table;
			$join_key = $key;
		}
		# add LEFT JOINs for each multiple field to the dataset table
		foreach my $multiple (@{$joins->{$datasetid}->{'multiple'}})
		{
			# default to using the join_key (should be right 99% of the time)
			$multiple->{key} ||= $join_key;
			# this will be different for a non-multiple InSubject
			$multiple->{right_key} ||= $multiple->{key};
			# we need to alias the sub-table to enable ANDs
			my $alias = ++$idx . "_" . $join_table;
			push @joins, _sql_left_join($db,
				[ $join_table, $alias ],
				$multiple->{key},
				[ $multiple->{table}, $multiple->{alias}, $multiple->{subquery} ],
				$multiple->{right_key} );
			# now apply INNER JOINs to this field (e.g. for subjects)
			foreach my $inner (@{$multiple->{'inner'}||=[]})
			{
				$inner->{right_key} ||= $inner->{key};
				$joins[$#joins] .= _sql_inner_join($db,
					$multiple->{alias},
					$inner->{key},
					[ $inner->{table}, $inner->{alias} ],
					$inner->{right_key} );
			}
			# add the logic for joining our sub-table alias to the parent table
			push @join_logic, sprintf("%s.%s=%s.%s",
				$db->quote_identifier($join_table),
				$db->quote_identifier($join_key),
				$db->quote_identifier($alias),
				$db->quote_identifier($join_key));
		}
	}

	$sql .= " FROM ".join(',', @joins);

	my $logic = $self->get_query_logic( %opts );
	push @join_logic, $logic if length($logic);
	if( scalar(@join_logic) )
	{
		$sql .= " WHERE (".join(") AND (", @join_logic).")";
	}

	# if we have multiple tables we need to group-by the eprintid to get unique
	# eprintids
	if( @joins > 1 || scalar @orders )
	{
		$sql .= " GROUP BY ".$db->quote_identifier($table,$key_field_name);
		# oracle needs every ORDER BY field to be defined in the GROUP BY
		if( scalar @orders )
		{
			for(my $i = 0; $i < @orders; $i+=2)
			{
				$sql .= ",".$db->quote_identifier("OV",$orders[$i]);
			}
		}
	}

	# add the ORDER BY if the search is ordered
	if( scalar @orders )
	{
		$sql .= " ORDER BY ";
		for(my $i = 0; $i < @orders; $i+=2)
		{
			$sql .= ", " if $i != 0;
			$sql .= $db->quote_identifier("OV", $orders[$i]) . " ". $orders[$i+1];
		}
	}

	if( defined $cachemap )
	{
		my $cache_table = $db->begin_cache_table( $cachemap, $dataset->get_key_field );
		$sql = "INSERT INTO ".$db->quote_identifier($cache_table)." (".$db->quote_identifier($key_field_name).") ".$sql;
#print STDERR "EXECUTING: $sql\n";
		$db->do($sql);
		$db->finish_cache_table( $cachemap );
		$sql = "SELECT ".$db->quote_identifier($key_field_name)." FROM ".$db->quote_identifier($cache_table)." ORDER BY ".$db->quote_identifier("pos");
	}

#print STDERR "EXECUTING: $sql\n";
	my $sth = $db->prepare_select( $sql, limit => $opts{limit} );
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

=item $scond->get_query_joins( $joins, %opts )

Populates $joins with the tables required for this search condition.

	joins = {
		DATASET_ID => {
			"multiple" => [
				{
					table => TABLE_NAME,
					alias => TABLE_ALIAS,
					key => KEY_COLUMN,
				},
			],
		},
	}

=cut

sub get_query_joins
{
	my( $self, $joins, %opts ) = @_;
}

=item $sql = $scond->get_query_logic( %opts )

Returns a SQL string that, if longer than zero chars, will be used as the logic in the WHERE part of the SQL query.

=cut

sub get_query_logic
{
	my( $self, %opts ) = @_;

	return "";
}

# _sql_inner_join( LEFT, LEFT_KEY, [ RIGHT, ALIAS ], RIGHT_KEY )
sub _sql_inner_join
{
	my( $db, $left, $left_key, $right, $right_key ) = @_;

	$right = [$right, $right] if !ref($right);

	return sprintf(" INNER JOIN %s %s ON %s.%s=%s.%s", map { $db->quote_identifier($_) }
		@$right,
		$left,
		$left_key,
		$right->[1],
		$right_key);
}

# _sql_left_join( [ LEFT, ALIAS ], LEFT_KEY, [ RIGHT, ALIAS ], RIGHT_KEY )
sub _sql_left_join
{
	my( $db, $left, $left_key, $right, $right_key ) = @_;

	$left = [$left, $left] if !ref($left);
	$right = [$right, $right] if !ref($right);

	if( !defined $left->[1] )
	{
		Carp::croak "Expected table-alias in left table spec";
	}
	if( !defined $right->[1] )
	{
		Carp::croak "Expected table-alias in right table spec";
	}

	my @right_table;
	if( defined $right->[2] ) # subquery
	{
		@right_table = ($right->[2], $db->quote_identifier($right->[1]));
	}
	else
	{
		@right_table = map { $db->quote_identifier($_) } @$right[0,1];
	}

	return sprintf("%s %s LEFT JOIN %s %s ON %s.%s=%s.%s",
		(map { $db->quote_identifier($_) } @$left[0,1]),
		@right_table[0,1],
		(map { $db->quote_identifier($_) }
		$left->[1],
		$left_key,
		$right->[1],
		$right_key) );
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

sub _v3_process_groupby
{
	my( $self, %opts ) = @_;

	my $session = $opts{session};
	my $db = $opts{session}->get_database;

	my $dataset = $opts{dataset};
	my $groupby = $opts{field};

	if( $groupby->get_dataset->confid ne $dataset->confid )
	{
		EPrints::abort( "Can only only group-by on field in main dataset" );
	}

	my $joins = {};
	# populate $joins with all the required tables
	$self->get_query_joins( $joins, %opts );

	my $table = $dataset->get_sql_table_name;
	my $key_field_name = $dataset->get_key_field->get_sql_name;

	my @joins;

	my $sql = "SELECT ";
	if( $groupby->get_property( "multiple" ) )
	{
		my $sub_table = $dataset->get_sql_sub_table_name( $groupby );
		$sql .= join(",", map { 
			$db->quote_identifier($sub_table, $_)
		} $groupby->get_sql_names() );
		push @joins,
			$db->quote_identifier( $table ) . _sql_inner_join($db,
					$table,
					$key_field_name,
					$sub_table,
					$key_field_name );
	}
	else
	{
		$sql .= join(",", map { 
			$db->quote_identifier($table, $_)
		} $groupby->get_sql_names() );
		push @joins, $db->quote_identifier( $table );
	}
	$sql .= ",COUNT(DISTINCT ".$db->quote_identifier($table,$key_field_name).") ";

	my $idx = 0;
	my @join_logic;
	foreach my $datasetid (keys %$joins)
	{
		$joins->{$datasetid}->{'multiple'} ||= [];
		my $join_table = $table;
		my $join_key = $key_field_name;
		# join to the non-main dataset
		if( $datasetid ne $dataset->confid )
		{
			# join to the main dataset by aliasing the main dataset and then
			# doing a LEFT JOIN to the new dataset
			my $alias = ++$idx . "_" . $table;
			my $join_dataset = $joins->{$datasetid}->{dataset};
			my $table = $join_dataset->get_sql_table_name;
			my $key = $join_dataset->get_key_field->get_sql_name;
			my $left_key;
			my $right_key;
# TODO: this patches over the missing join_path support but isn't the solution
				# this dataset is child of main dataset
				if( $join_dataset->has_field( $key_field_name ) )
				{
					$left_key = $right_key = $key_field_name;
				}
				# main dataset is a child of this dataset
				elsif( $dataset->has_field( $join_dataset->get_key_field->get_sql_name ) )
				{
					$left_key = $right_key = $join_dataset->get_key_field->get_sql_name;
				}
				else
				{
					EPrints::abort( "Unknown join between datasets ".$dataset->confid." and ".$join_dataset->confid );
				}
			push @joins, _sql_left_join($db,
				[ $join_table, $alias ],
				$left_key,
				$table,
				$right_key ); # TODO: per-dataset join-path
			# assert the INNER JOIN between the alias and main dataset
			push @join_logic, sprintf("%s.%s=%s.%s",
				$db->quote_identifier($join_table),
				$db->quote_identifier($join_key),
				$db->quote_identifier($alias),
				$db->quote_identifier($join_key));
			# any fields will need to join to the new dataset
			$join_table = $table;
			$join_key = $key;
		}
		# add LEFT JOINs for each multiple field to the dataset table
		foreach my $multiple (@{$joins->{$datasetid}->{'multiple'}})
		{
			# default to using the join_key (should be right 99% of the time)
			$multiple->{key} ||= $join_key;
			# this will be different for a non-multiple InSubject
			$multiple->{right_key} ||= $multiple->{key};
			# we need to alias the sub-table to enable ANDs
			my $alias = ++$idx . "_" . $join_table;
			push @joins, _sql_left_join($db,
				[ $join_table, $alias ],
				$multiple->{key},
				[ $multiple->{table}, $multiple->{alias}, $multiple->{subquery} ],
				$multiple->{right_key} );
			# now apply INNER JOINs to this field (e.g. for subjects)
			foreach my $inner (@{$multiple->{'inner'}||=[]})
			{
				$inner->{right_key} ||= $inner->{key};
				$joins[$#joins] .= _sql_inner_join($db,
					$multiple->{alias},
					$inner->{key},
					[ $inner->{table}, $inner->{alias} ],
					$inner->{right_key} );
			}
			# add the logic for joining our sub-table alias to the parent table
			push @join_logic, sprintf("%s.%s=%s.%s",
				$db->quote_identifier($join_table),
				$db->quote_identifier($join_key),
				$db->quote_identifier($alias),
				$db->quote_identifier($join_key));
		}
	}

	$sql .= " FROM ".join(',', @joins);

	my $logic = $self->get_query_logic( %opts );
	push @join_logic, $logic if length($logic);
	if( scalar(@join_logic) )
	{
		$sql .= " WHERE (".join(") AND (", @join_logic).")";
	}

	$sql .= " GROUP BY ";
	if( $groupby->get_property( "multiple" ) )
	{
		$sql .= join(",", map { 
			$db->quote_identifier($dataset->get_sql_sub_table_name($groupby), $_)
		} $groupby->get_sql_names() );
	}
	else
	{
		$sql .= join(",", map { 
			$db->quote_identifier($dataset->get_sql_table_name, $_)
		} $groupby->get_sql_names() );
	}

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
	my( $self, $internal ) = @_;

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

