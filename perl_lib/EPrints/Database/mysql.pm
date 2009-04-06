######################################################################
#
# EPrints::Database::mysql
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

B<EPrints::Database::mysql> - custom database methods for MySQL DB

=head1 DESCRIPTION

MySQL database wrapper.

=head2 MySQL-specific Annoyances

MySQL does not support sequences.

MySQL is (by default) lax about truncation.

=head1 METHODS

=over 4

=cut

######################################################################
#
# INSTANCE VARIABLES:
#
#  $self->{session}
#     The EPrints::Session which is associated with this database 
#     connection.
#
#  $self->{debug}
#     If true then SQL is logged.
#
#  $self->{dbh}
#     The handle on the actual database connection.
#
######################################################################

package EPrints::Database::mysql;

use EPrints;

use EPrints::Database qw( :sql_types );
@ISA = qw( EPrints::Database );

our $I18L = {
	en => {
		collate => "utf8_general_ci",
	},
	de => {
		collate => "utf8_unicode_ci",
	},
};

use strict;

######################################################################
=pod

=item $version = $db->get_server_version

Return the database server version.

=cut
######################################################################

sub get_server_version
{
	my( $self ) = @_;

	my $sql = "SELECT VERSION();";
	my( $version ) = $self->{dbh}->selectrow_array( $sql );
	return "MySQL $version";
}

sub mysql_version_from_dbh
{
	my( $dbh ) = @_;
	my $sql = "SELECT VERSION();";
	my( $version ) = $dbh->selectrow_array( $sql );
	$version =~ m/^(\d+).(\d+).(\d+)/;
	return $1*10000+$2*100+$3;
}

######################################################################
=pod

=item $n = $db->create_counters()

Create and initialise the counters.

=cut
######################################################################

sub create_counters
{
	my( $self ) = @_;

	my $counter_ds = $self->{session}->get_repository->get_dataset( "counter" );
	
	# The table creation SQL
	my $table = $counter_ds->get_sql_table_name;
	
	my $rc = $self->_create_table( $table, ["countername"], [
		$self->get_column_type( "countername", SQL_VARCHAR, SQL_NOT_NULL , 255 ),
		$self->get_column_type( "counter", SQL_INTEGER, SQL_NOT_NULL ),
	]);

	$rc &&= $self->SUPER::create_counters();
	
	# Everything OK
	return $rc;
}

######################################################################
=pod

=item $boolean = $db->has_table( $tablename )

Return true if the a table of the given name exists in the database.

=cut
######################################################################

sub has_table
{
	my( $self, $tablename ) = @_;

	my $sth = $self->prepare("SHOW TABLES LIKE ".$self->quote_value($tablename));
	$sth->execute;
	my $rc = defined $sth->fetch ? 1 : 0;
	$sth->finish;

	return $rc;
}

######################################################################
=pod

=item $boolean = $db->has_column( $tablename, $columnname )

Return true if the a table of the given name has a column named $columnname in the database.

=cut
######################################################################

sub has_column
{
	my( $self, $table, $column ) = @_;

	my $rc = 0;

	my $sth = $self->{dbh}->column_info( undef, undef, $table, '%' );
	while(!$rc && (my $row = $sth->fetch))
	{
		my $column_name = $row->[$sth->{NAME_lc_hash}{column_name}];
		$rc = 1 if $column_name eq $column;
	}
	$sth->finish;

	return $rc;
}

sub connect
{
	my( $self ) = @_;

	my $rc = $self->SUPER::connect();

	if( $rc )
	{
		$self->do("SET NAMES 'utf8'");
	}

	return $rc;
}

######################################################################
=pod

=item $success = $db->has_counter( $counter )

Returns true if $counter exists.

=cut
######################################################################

sub has_counter
{
	my( $self, $name ) = @_;

	my $sql = "SELECT 1 FROM `counters` WHERE `countername`=".$self->quote_value( $name );

	my $sth = $self->prepare($sql);
	$self->execute( $sth, $sql );

	return defined $sth->fetch;
}

sub create_counter
{
	my( $self, $name ) = @_;

	return $self->insert( "counters", ["countername", "counter"], [$name, 0] );
}

sub drop_counter
{
	my( $self, $name ) = @_;

	return $self->delete_from( "counters", ["countername"], [$name] );
}

sub remove_counters
{
	my( $self ) = @_;

	my $counter_ds = $self->{session}->get_repository->get_dataset( "counter" );
	my $table = $counter_ds->get_sql_table_name;
	
	$self->drop_table( $table );
}

######################################################################
=pod

=item $n = $db->counter_next( $counter )

Return the next unused value for the named counter. Returns undef if 
the counter doesn't exist.

=cut
######################################################################

sub counter_next
{
	my( $self, $counter ) = @_;

	my $ds = $self->{session}->get_repository->get_dataset( "counter" );

	# Update the counter
	my $table = $ds->get_sql_table_name;
	my $sql = "UPDATE ".$self->quote_identifier($table)." SET counter=".
		"LAST_INSERT_ID(counter+1) WHERE ".$self->quote_identifier("countername")." = ".$self->quote_value($counter);
	
	# Send to the database
	my $rows_affected = $self->do( $sql );

	# Return with an error if unsuccessful
	return( undef ) unless( $rows_affected==1 );

	# Get the value of the counter
	$sql = "SELECT LAST_INSERT_ID();";
	my @row = $self->{dbh}->selectrow_array( $sql );

	return( $row[0] );
}

######################################################################
=pod

=item $db->counter_minimum( $counter, $value )

Ensure that the counter is set no lower that $value. This is used when
importing eprints which may not be in scrict sequence.

=cut
######################################################################

sub counter_minimum
{
	my( $self, $counter, $value ) = @_;

	my $ds = $self->{session}->get_repository->get_dataset( "counter" );

	$value+=0; # ensure numeric!

	# Update the counter to be at least $value
	my $sql = "UPDATE ".$ds->get_sql_table_name()." SET counter="
		. "CASE WHEN $value>counter THEN $value ELSE counter END"
		. " WHERE countername = ".$self->quote_value($counter);
	$self->do( $sql );
}


######################################################################
=pod

=item $db->counter_reset( $counter )

Return the counter. Use with cautiuon.

=cut
######################################################################

sub counter_reset
{
	my( $self, $counter ) = @_;

	my $ds = $self->{session}->get_repository->get_dataset( "counter" );

	# Update the counter	
	my $sql = "UPDATE ".$ds->get_sql_table_name()." ";
	$sql.="SET counter=0 WHERE countername = ".$self->quote_value($counter);
	
	# Send to the database
	$self->do( $sql );
}

sub _cache_from_TABLE
{
	my( $self, $cachemap, $dataset, $srctable, $order, $logic ) = @_;

	my $sql;

	my $cache_table  = $cachemap->get_sql_table_name;
	my $keyfield = $dataset->get_key_field();
	my $Q_keyname = $self->quote_identifier($keyfield->get_name);
	$logic ||= [];

	$sql = "ALTER TABLE $cache_table MODIFY `pos` INT NOT NULL AUTO_INCREMENT";
	$self->do($sql);

	$sql = "INSERT INTO $cache_table ($Q_keyname) SELECT B.$Q_keyname FROM $srctable B";
	if( defined $order )
	{
		$sql .= " LEFT JOIN ".$self->quote_identifier($dataset->get_ordervalues_table_name($self->{session}->get_langid()))." O";
		$sql .= " ON B.$Q_keyname = O.$Q_keyname";
	}
	if( scalar @$logic )
	{
		$sql .= " WHERE ".join(" AND ", @$logic);
	}
	if( defined $order )
	{
		$sql .= " ORDER BY ";
		my $first = 1;
		foreach( split( "/", $order ) )
		{
			$sql .= ", " if( !$first );
			my $desc = 0;
			if( s/^-// ) { $desc = 1; }
			my $field = EPrints::Utils::field_from_config_string(
					$dataset,
					$_ );
			$sql .= "O.".$self->quote_identifier($field->get_sql_name());
			$sql .= " DESC" if $desc;
			$first = 0;
		}
	}
	$self->do( $sql );
}

######################################################################
=pod

=item $db->index_queue( $datasetid, $objectid, $fieldname );

Queues the field of the specified object to be reindexed.

=cut
######################################################################

sub index_queue
{
	my( $self, $datasetid, $objectid, @fieldnames ) = @_; 

	my $table = "index_queue";

	# SYSDATE is the date/time at the point of insertion, but is supported
	# by most databases unlike NOW(), which is only in MySQL
	for(@fieldnames)
	{
		$self->insert_quoted( $table, ["field","added"], [
			$self->quote_value("$datasetid.$objectid.$_"),
			"SYSDATE()"
		]);
	}
}

sub get_default_charset { "utf8" }

sub get_default_collation
{
	my( $self, $langid ) = @_;

	return exists($I18L->{$langid}) ? $I18L->{$langid}->{collate} : undef;
}

# Not supported by DBD::mysql?
sub get_primary_key
{
	my( $self, $table ) = @_;

	my $sth = $self->prepare( "DESCRIBE ".$self->quote_identifier($table) );
	$sth->execute;

	my @COLS;
	while(my $row = $sth->fetch)
	{
		push @COLS, $row->[0] if $row->[3] eq 'PRI';
	}

	return @COLS;
}

sub get_column_collation
{
	my( $self, $table, $column ) = @_;

	my $sth = $self->prepare( "SHOW FULL COLUMNS FROM ".$self->quote_identifier($table)." LIKE ".$self->quote_value($column) );
	$sth->execute;

	my $collation;
	while(my $row = $sth->fetch)
	{
		$collation = $row->[$sth->{NAME_lc_hash}{"collation"}];
	}

	return $collation;
}

1; # For use/require success

######################################################################
=pod

=back

=cut

