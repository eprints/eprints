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

use Data::Dumper;

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

	my $tables = $self->get_tables( $session );

	return $self->run_tables( $session, $tables );
}

=item $cond->get_query_joins( $joins, %opts )

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

=item $sql = $cond->get_query_logic( %opts )

Returns some raw SQL that, if longer than zero chars, will be used as the logic in the WHERE part of the SQL query.

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

	return sprintf("%s %s LEFT JOIN %s %s ON %s.%s=%s.%s", map { $db->quote_identifier($_) }
		@$left,
		@$right,
		$left->[1],
		$left_key,
		$right->[1],
		$right_key);
}

sub process_groupby
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
			my $dataset = $joins->{$datasetid}->{dataset};
			my $table = $dataset->get_sql_table_name;
			my $key = $dataset->get_key_field->get_sql_name;
			push @joins, _sql_left_join($db,
				[ $join_table, $alias ],
				$join_key,
				$table,
				$join_key ); # TODO: per-dataset join-path
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
				[ $multiple->{table}, $multiple->{alias} ],
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

print STDERR "EXECUTING: $sql\n";
	my $sth = $db->prepare_select( $sql );
	$db->execute($sth, $sql);

	my( @values, @counts ) = @_;

	while(my @row = $sth->fetchrow_array)
	{
		push @values, $groupby->value_from_sql_row( $session, \@row );
		push @counts, $row[0];
	}

	return( \@values, \@counts );
}

sub process_v3
{
	my( $self, %opts ) = @_;

	my $session = $opts{session};
	my $db = $opts{session}->get_database;

	my $dataset = $opts{dataset};

	my $table = $dataset->get_sql_table_name;
	my $q_table = $db->quote_identifier( $table );

	my $key_field_name = $dataset->get_key_field->get_sql_name;
	my $q_key_field_name = $db->quote_identifier( $key_field_name );

	# SELECT matching ids from the main dataset table
	my $sql = "SELECT DISTINCT ".$db->quote_identifier($table,$key_field_name);

	# calculate the tables we need (with appropriate joins)
	my @joins;

	# main LEFT JOIN ordervalues
	if( defined $opts{order} )
	{
		my $ov_table = $dataset->get_ordervalues_table_name( $session->get_langid );
		push @joins, _sql_left_join($db,
			$table,
			$key_field_name,
			[$ov_table, "OV"],
			$key_field_name );
	}
	# main
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
			my $dataset = $joins->{$datasetid}->{dataset};
			my $table = $dataset->get_sql_table_name;
			my $key = $dataset->get_key_field->get_sql_name;
			push @joins, _sql_left_join($db,
				[ $join_table, $alias ],
				$join_key,
				$table,
				$join_key ); # TODO: per-dataset join-path
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
				[ $multiple->{table}, $multiple->{alias} ],
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

	if( defined $opts{order} )
	{
		$sql .= " ORDER BY ";
		my $first = 1;
		foreach my $fieldname ( split( "/", $opts{order} ) )
		{
			$sql .= ", " if( !$first );
			$first = 0;
			my $desc = 0;
			if( $fieldname =~ s/^-// ) { $desc = 1; }
			my $field = EPrints::Utils::field_from_config_string( $dataset, $fieldname );
			$sql .= $db->quote_identifier( "OV", $field->get_sql_name() );
			$sql .= " DESC" if $desc;
		}
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

sub process_v2
{
	my( $self, %opts ) = @_;

	my $session = $opts{session};
	my $database = $opts{session}->get_database;

	my $qdata = { alias_count=>0, aliases=>{} };
	#$session->get_database->set_debug( 1 );

	my $qt = $self->get_query_tree( $session, $qdata );

	my $select;
	my $last_key_id;
	my @tables = ();

	if( defined $opts{order} )
	{
		$qdata->{aliases}->{order_table} = {
			id_field => "OV.".$opts{dataset}->get_key_field()->get_name(),
			table => $opts{dataset}->get_ordervalues_table_name($opts{session}->get_langid()),
			join_type => "left",
			alias => "OV",
		};
	}

	my @aliases = sort table_order_fn values %{$qdata->{aliases}};
	if( $aliases[0]->{join_type} ne "inner" )
	{
		# forced to add a new first table to be inner joined.
		unshift @aliases, {
			id_field => $opts{dataset}->get_key_field->get_name(), 
			table => $opts{dataset}->get_sql_table_name(),
			join_type => "inner",
			alias => "MAIN",
		};
	}

	foreach my $alias ( @aliases )
	{
		if( !defined $select ) 
		{
			# first item
			if( !defined $alias->{id_field} )
			{
				EPrints::abort( "Internal search error: no primary select field. ".Dumper( \@aliases ) );
			}
			$select = $alias->{id_field};
			push @tables, $alias->{table}." AS ".$alias->{alias};
		}
		else
		{
			if( defined $alias->{id_field} )
			{	
				$alias->{join_on} = $alias->{id_field}."=".$last_key_id;
			}
			if( !defined $alias->{join_on} )
			{
				EPrints::abort( "Internal search error: nothing to join. ".Dumper( \@aliases ) );
			}
			push @tables, uc( $alias->{join_type} )." JOIN ".$alias->{table}." AS ".$alias->{alias}." ON ".$alias->{join_on};
		}
		
		$last_key_id = $alias->{id_field};
	}

	my $sql;
	$sql  = "SELECT DISTINCT $select ";
	$sql .= "FROM ".join( " ", @tables )." ";
	$sql .= "WHERE "._process_wheres( $qt );

	if( defined $opts{order} )
	{
		$sql .= " ORDER BY ";
		my $first = 1;
		foreach my $fieldname ( split( "/", $opts{order} ) )
		{
			$sql .= ", " if( !$first );
			my $desc = 0;
			if( $fieldname =~ s/^-// ) { $desc = 1; }
			my $field = EPrints::Utils::field_from_config_string( $opts{dataset}, $fieldname );
			$sql .= "OV.".$database->quote_identifier( $field->get_sql_name() );
			$sql .= " DESC" if $desc;
			$first = 0;
		}
	}

#print STDERR "EXECUTING: $sql\n";
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

sub table_order_fn
{
	my $j = defined $a->{join_on} <=> defined $b->{join_on};
	return $j unless $j == 0;

	# inner joins first
	my $jt = ($b->{join_type} eq "inner") <=> ($a->{join_type} eq "inner");
	return $jt unless $jt == 0;

	# MAIN table first if possible
	return ($b->{alias} eq "MAIN") <=> ($a->{alias} eq "MAIN");
}

sub _process_wheres
{
	my( $qt ) = @_;

	my $type = shift @{$qt};
	
	if( $type eq "AND" || $type eq "OR" )
	{
		my @parts = ();
		foreach my $sub_where ( @{$qt} )
		{
			push @parts, _process_wheres( $sub_where );
		}
		return "(".join( " ".$type." ", @parts ).")";
	}

	if( $type eq "ITEM" )
	{
		my $a = $qt->[-1];
		my $where = $a->{where};
	
		$where =~ s/d41d8cd98f00b204e9800998ecf8427e/$a->{alias}/g;
		return $where;
	}
	
	die "Unknown where whotsit bit";
}

sub get_query_tree
{
	my( $self, $session, $qdata, $mergemap ) = @_;

	my $tables = $self->get_tables( $session );
	my $join_path = "";

	my $main_path = "/".$self->{dataset}->get_key_field->get_name().
			"/inner".
			"/".$self->{dataset}->get_sql_table_name();
	my $prev_tinfo;
	foreach my $tinfo ( @{$tables} )
	{
		$tinfo->{join_type} = "inner" unless defined $tinfo->{join_type};
		$join_path .= "/".$tinfo->{left}."/".$tinfo->{join_type}."/".$tinfo->{table};
		$tinfo->{join_path} = $join_path;

		if( $tinfo->{join_path} eq $main_path && defined $qdata->{aliases}->{MAIN} )
		{
			$tinfo->{alias} = "MAIN";
		}
		elsif( defined $mergemap && defined $mergemap->{$join_path} )
		{
			$tinfo->{alias} = $mergemap->{$join_path};
		}
		else
		{
			if( $tinfo->{join_path} eq $main_path )
			{
				$tinfo->{alias} = "MAIN";
			}
			else
			{
				$qdata->{alias_count}++;
				$tinfo->{alias} = "T".$qdata->{alias_count};
			}
			my $new_table = { 
				alias=>$tinfo->{alias}, 
				table=>$tinfo->{table},
				join_type=>$tinfo->{join_type},
			};
			if( defined $prev_tinfo )
			{
				$new_table->{join_on} = $prev_tinfo->{alias}.".".$prev_tinfo->{right} ."=".$tinfo->{alias}.".".$tinfo->{left};
			}
			else
			{
				$new_table->{id_field} = $tinfo->{alias}.".".$tinfo->{left};
			}
			$qdata->{aliases}->{$tinfo->{alias}} = $new_table;
			if( defined $mergemap )
			{
				$mergemap->{$join_path} = $tinfo->{alias};
			}
		}

		$prev_tinfo = $tinfo;
		if( defined $tinfo->{right} ) { $join_path.="/".$tinfo->{right}; }
	}

	return [ "ITEM", @$tables ];
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

