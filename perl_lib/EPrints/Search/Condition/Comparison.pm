######################################################################
#
# EPrints::Search::Condition::Comparison
#
######################################################################
#
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

@ISA = qw( EPrints::Search::Condition );

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

sub _logic_time
{
	my( $self, %opts ) = @_;
	
	my $repository = $opts{repository};
	my $database = $repository->get_database;
	my $table = $opts{table};
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
	if( !$self->{field}->isa( "EPrints::MetaField::Time" ) && $nparts > 3 )
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
				push @and, $database->quote_identifier($table,$sql_col."_".$timemap->[$j])." ".$o." ".EPrints::Database::prep_int( $parts[$j] ); 
			}
			push @or, "( ".join( " AND ", @and )." )";
		}
	}

	if( $eq )
	{
		my @and = ();
		for( my $i=0;$i<$nparts;++$i )
		{
			push @and, $database->quote_identifier($table,$sql_col."_".$timemap->[$i])." = ".EPrints::Database::prep_int( $parts[$i] ); 
		}
		push @or, "( ".join( " AND ", @and )." )";
	}

	return "(".join( " OR ", @or ).")";
}

sub joins
{
	my( $self, %opts ) = @_;

	my $db = $opts{repository}->get_database;
	my $prefix = $opts{prefix};
	$prefix = "" if !defined $prefix;

	# parent dataset
	if( $self->dataset->confid eq $opts{dataset}->confid )
	{
		# parent table
		if( !$self->{field}->get_property( "multiple" ) )
		{
			return ();
		}
		elsif( 
			$self->{field}->isa( "EPrints::MetaField::Compound" ) &&
			!$self->{field}->isa( "EPrints::MetaField::Dataobjref" )
		)
		{
			my @joins;
			foreach my $f (@{$self->{field}->property( "fields_cache" )})
			{
				my $table = $f->{dataset}->get_sql_sub_table_name( $f );
				push @joins, {
					type => "inner",
					table => $table,
					alias => "$prefix$table",
					key => $self->dataset->get_key_field->get_sql_name,
				};
			}
			return @joins;
		}
		else
		{
			my $table = $self->table;
			return {
				type => "inner",
				table => $table,
				alias => "$prefix$table",
				key => $self->dataset->get_key_field->get_sql_name,
			};
		}
	}
	# join to another dataset
	else
	{
		my @joins = $self->join_path(
				$opts{dataset},
				%opts,
				prefix => $prefix,
			);
		if( $self->{field}->get_property( "multiple" ) )
		{
			my $main_key = $self->dataset->get_key_field->get_sql_name;
			my $table = $self->table;
			# link to the last join, which is always the table being joined to
			push @joins, {
				type => "inner",
				table => $table,
				alias => "${prefix}$table",
				logic => $db->quote_identifier( $joins[-1]->{alias}, $main_key )."=".$db->quote_identifier( "${prefix}$table", $main_key ),
			};
		}
		return @joins;
	}
}

sub logic
{
	my( $self, %opts ) = @_;

	my $db = $opts{repository}->get_database;
	my $prefix = $opts{prefix};
	$prefix = "" if !defined $prefix;
	if( $self->table eq $opts{dataset}->get_sql_table_name )
	{
		$prefix = "";
	}

	my $table = $prefix . $self->table;
	my $field = $self->{field};
	my $sql_name = $field->get_sql_name;

	if( $field->isa( "EPrints::MetaField::Name" ) )
	{
		my @logic;
		for(qw( given family ))
		{
			push @logic, sprintf("%s %s %s",
				$db->quote_identifier( $table, "$sql_name\_$_" ),
				$self->{op},
				$db->quote_value( $self->{params}->[0]->{$_} ) );
		}
		return "(".join(") AND (", @logic).")";
	}
	elsif( $field->isa( "EPrints::MetaField::Compound" ) )
	{
		my @logic;
		my $prev_table;
		foreach my $f (@{$self->{field}->property( "fields_cache" )})
		{
			local $self->{field} = $f;
			my $table = $prefix . $self->table;
			if( $f->property( "multiple" ) )
			{
				if( $prev_table )
				{
					push @logic, sprintf("%s %s %s",
						$db->quote_identifier( $prev_table, "pos" ),
						"=",
						$db->quote_identifier( $table, "pos" ) );
				}
				$prev_table = $table;
			}
			push @logic, sprintf("%s %s %s",
					$db->quote_identifier( $table, $f->get_sql_name ),
					$self->{op},
					$db->quote_value( $self->{params}->[0]->{$f->property( "sub_name" )} ) );
		}
		return "(".join(") AND (", @logic).")";
	}
	elsif( $field->isa( "EPrints::MetaField::Multipart" ) )
	{
		my @logic;
		for($field->parts)
		{
			push @logic, sprintf("%s %s %s",
				$db->quote_identifier( $table, "$sql_name\_$_" ),
				$self->{op},
				$db->quote_value( $self->{params}->[0]->{$_} ) );
		}
		return "(".join(") AND (", @logic).")";
	}
	elsif( $field->isa( "EPrints::MetaField::Date" ) )
	{
		return $self->_logic_time( %opts, table => $table );
	}
	elsif( $field->isa( "EPrints::MetaField::Int" ) )
	{
		return sprintf("%s %s %s",
			$db->quote_identifier( $table, $sql_name ),
			$self->{op},
			EPrints::Database::prep_int( $self->{params}->[0] ) );
	}
	else
	{
		return sprintf("%s %s %s",
			$db->quote_identifier( $table, $sql_name ),
			$self->{op},
			$db->quote_value( $self->{params}->[0] ) );
	}
}

sub join_keys
{
	my( $self, $source, %opts ) = @_;

	my $target = $self->dataset;
	my $field = $self->{field};

	if(
		$field->has_property( "join_path" ) &&
		defined(my $join_path = $field->property( "join_path" ))
	  )
	{
		my( $left, $right ) = (
				$join_path->[0]->[0],
				$join_path->[1]->[0],
			);
		$right = $target->key_field if !defined $right;
		if( $left->isa( "EPrints::MetaField::Subobject" ) )
		{
			$right = $target->field( $left->property( "dataobj_fieldname" ) );
			$left = $source->key_field;
		}
		return( $left, $right );
	}

	my $left = $source->get_key_field;
	my $right = $target->get_key_field;

	my @join;

	# document.docid = file.objectid AND file.datasetid = 'document'
	if(
		$target->dataobj_class->isa( "EPrints::DataObj::SubObject" ) &&
		$target->has_field( "datasetid" ) &&
		$target->has_field( "objectid" )
	  )
	{
		@join = ( $left, $target->field( "objectid" ) );
	}
	# eprint.userid = user.userid
	elsif( $source->has_field( $right->name ) )
	{
		@join = ( $source->field( $right->name ), $right );
	}
	# eprint.eprintid = document.eprintid
	elsif( $target->has_field( $left->name ) )
	{
		@join = ( $left, $target->field( $left->name ) );
	}

	return @join;
}

# return the logic to join two datasets together
sub join_path
{
	my( $self, $source, %opts ) = @_;

	my $db = $opts{repository}->database;

	my $target = $self->dataset;

	my( $left, $right ) = $self->join_keys( $source, %opts );
	if( !defined $left )
	{
		EPrints::abort( "Can't create join path for field ".$self->dataset->base_id.".".$self->{field}->get_name.": ".$source->confid." -> ".$target->confid );
	}

	my @joins;
	my @logic;

	my $left_table = $source->get_sql_table_name;
	my $left_alias = $left_table;

	# add a join between the LHS main table and field sub-table
	if( $left->property( "multiple" ) )
	{
		my $main_table = $source->get_sql_table_name;
		my $key_field = $source->key_field;

		$left_table = $source->get_sql_sub_table_name( $left );
		$left_alias = $opts{prefix} . $left_table;

		push @joins, {
			type => "inner",
			table => $left_table,
			alias => $left_alias,
			logic => join('=',
				$db->quote_identifier( $main_table, $key_field->get_sql_name ),
				$db->quote_identifier( $left_alias, $key_field->get_sql_name )
			),
		};
	}

	my $right_table = $target->get_sql_table_name;
	my $right_alias = $opts{prefix} . $right_table;

	# add a join between the RHS field sub-table and main table
	if( $right->property( "multiple" ) )
	{
		my $main_table = $target->get_sql_table_name;
		my $alias = $opts{prefix} . $main_table;
		my $key_field = $target->key_field;

		$right_table = $target->get_sql_sub_table_name( $right );
		$right_alias = $opts{prefix} . $right_table;

		push @joins, {
			type => "inner",
			table => $main_table,
			alias => $alias,
			logic => join('=',
				$db->quote_identifier( $right_alias, $key_field->get_sql_name ),
				$db->quote_identifier( $alias, $key_field->get_sql_name )
			),
		};
	}

	push @logic, join '=',
		$db->quote_identifier( $left_alias, $left->get_sql_name ),
		$db->quote_identifier( $right_alias, $right->get_sql_name );

	# add the implied datasetid filter for dynamically typed Subobjects
	if(
		$target->dataobj_class->isa( "EPrints::DataObj::SubObject" ) &&
		$target->has_field( "datasetid" )
	  )
	{
		push @logic, join '=',
			$db->quote_identifier( $right_alias, "datasetid" ),
			$db->quote_value( $source->base_id );
	}

	push @joins, {
		type => "inner",
		table => $right_table,
		alias => $right_alias,
		logic => join(' AND ', @logic),
	};

	return @joins;
}

1;

=head1 COPYRIGHT

=for COPYRIGHT BEGIN

Copyright 2000-2011 University of Southampton.

=for COPYRIGHT END

=for LICENSE BEGIN

This file is part of EPrints L<http://www.eprints.org/>.

EPrints is free software: you can redistribute it and/or modify it
under the terms of the GNU Lesser General Public License as published
by the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

EPrints is distributed in the hope that it will be useful, but WITHOUT
ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser General Public
License for more details.

You should have received a copy of the GNU Lesser General Public
License along with EPrints.  If not, see L<http://www.gnu.org/licenses/>.

=for LICENSE END

