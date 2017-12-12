######################################################################
#
# EPrints::Database::mysql
#
######################################################################
#
#
######################################################################


=pod

=for Pod2Wiki

=head1 NAME

B<EPrints::Database::mysql> - custom database methods for MySQL DB

=head1 SYNOPSIS

	$c->{dbdriver} = 'mysql';
	# $c->{dbhost} = 'localhost';
	# $c->{dbport} = '3316';
	$c->{dbname} = 'myrepo';
	$c->{dbuser} = 'bob';
	$c->{dbpass} = 'asecret';
	# $c->{dbengine} = 'InnoDB';

=head1 DESCRIPTION

MySQL database wrapper.

Foreign keys will be defined if you use a DB engine that supports them (e.g. InnoDB).

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

sub create
{
	my( $self, $username, $password ) = @_;

	my $repo = $self->{session}->get_repository;

	my $dbh = DBI->connect( EPrints::Database::build_connection_string( 
			dbdriver => "mysql",
			dbhost => $repo->get_conf("dbhost"),
			dbsock => $repo->get_conf("dbsock"),
			dbport => $repo->get_conf("dbport"),
			dbname => "mysql", ),
	        $username,
	        $password,
			{
				AutoCommit => 1,
				RaiseError => 0,
				PrintError => 0,
			} );

	return undef if !defined $dbh;

	$dbh->{RaiseError} = 1;

	my $dbuser = $repo->get_conf( "dbuser" );
	my $dbpass = $repo->get_conf( "dbpass" );
	my $dbname = $repo->get_conf( "dbname" );

	my $rc = 1;
	
	$rc &&= $dbh->do( "CREATE DATABASE IF NOT EXISTS ".$dbh->quote_identifier( $dbname )." DEFAULT CHARACTER SET ".$dbh->quote( $self->get_default_charset ) );

	$rc &&= $dbh->do( "GRANT ALL PRIVILEGES ON ".$dbh->quote_identifier( $dbname ).".* TO ".$dbh->quote_identifier( $dbuser )."\@".$dbh->quote("localhost")." IDENTIFIED BY ".$dbh->quote( $dbpass ) );

	$dbh->disconnect;

	$self->connect();

	return 0 if !defined $self->{dbh};

	return $rc;
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
		# always try to reconnect
		$self->{dbh}->{mysql_auto_reconnect} = 1;

		$self->do("SET NAMES 'utf8'");
		$self->do('SET @@session.optimizer_search_depth = 3;');
	}
	elsif( $DBI::err == 1040 )
	{
		EPrints->abort( "Error connecting to MySQL server: $DBI::errstr. To fix this increase max_connections in my.cnf:\n\n[mysqld]\nmax_connections=300\n" );
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

sub _cache_from_SELECT
{
	my( $self, $cachemap, $dataset, $select_sql ) = @_;

	my $cache_table  = $cachemap->get_sql_table_name;
	my $Q_pos = $self->quote_identifier( "pos" );
	my $key_field = $dataset->get_key_field();
	my $Q_keyname = $self->quote_identifier($key_field->get_sql_name);

	$self->do("SET \@i=0");

	my $sql = "";
	$sql .= "INSERT INTO ".$self->quote_identifier( $cache_table );
	$sql .= "($Q_pos, $Q_keyname)";
	$sql .= " SELECT \@i:=\@i+1, $Q_keyname";
	# MariaDB does not order sub-queries unless limited. Using limit of 2^31-1 in case any system is using a signed 32-bit integer.
	my $limit = " LIMIT 2147483647";
        $limit = "" if $select_sql =~ /LIMIT/;
        $sql .= " FROM ($select_sql$limit) ".$self->quote_identifier( "S" );

	$self->do( $sql );
}

sub get_default_charset { "utf8" }

sub get_default_collation
{
	my( $self, $langid ) = @_;

	return "utf8_bin";
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

sub get_number_of_keys
{
	my( $self, $table ) = @_;
	my $sth = $self->prepare( "DESCRIBE ".$self->quote_identifier($table) );
        $sth->execute;

        my $NUM_KEYS = 0;
        while(my $row = $sth->fetch)
	{
		if ( $row->[3] eq 'PRI' or $row->[3] eq 'MUL' or $row->[3] eq 'UNI' ) 
		{
			++$NUM_KEYS;
		}
	}
	return $NUM_KEYS;
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

# We'll do quote here, because DBD::mysql::quote_identifier is really slow
sub quote_identifier
{
	my( $self, @parts ) = @_;

	# we shouldn't get identifiers with '`' in
	return join(".", map {
		$_ =~ m/`/ ?
			EPrints::abort "Bad character in database identifier: $_" :
			"`$_`"
		} @parts);
}

sub _rename_table_field
{
	my( $self, $table, $field, $old_name ) = @_;

	my $rc = 1;

	my @names = $field->get_sql_names;
	my @types = $field->get_sql_type( $self->{session} );

	# work out what the old columns are called
	my @old_names;
	{
		local $field->{name} = $old_name;
		@old_names = $field->get_sql_names;
	}

	my @column_sql;
	for(my $i = 0; $i < @names; ++$i)
	{
		push @column_sql, sprintf("CHANGE %s %s",
				$self->quote_identifier($old_names[$i]),
				$types[$i]
			);
	}
	
	$rc &&= $self->do( "ALTER TABLE ".$self->quote_identifier($table)." ".join(",", @column_sql));

	return $rc;
}

sub _rename_field_ordervalues_lang
{
	my( $self, $dataset, $field, $old_name, $langid ) = @_;

	my $order_table = $dataset->get_ordervalues_table_name( $langid );

	my $sql_field = $field->create_ordervalues_field( $self->{session}, $langid );

	my( $col ) = $sql_field->get_sql_type( $self->{session} );

	my $sql = sprintf("ALTER TABLE %s CHANGE %s %s",
			$self->quote_identifier($order_table),
			$self->quote_identifier($old_name),
			$col
		);

	return $self->do( $sql );
}

sub prepare_regexp
{
	my( $self, $col, $value ) = @_;

	return "$col REGEXP $value";
}

sub sql_LIKE
{
	my( $self ) = @_;

	return " COLLATE utf8_general_ci LIKE ";
}

# This is a hacky method to support CI username/email lookups. Should be
# implemented as an option on searching (bigger change of search mechanisms?).

sub ci_lookup
{
	my( $self, $field, $value ) = @_;

	return if !defined $value; # Can't do a CI match on 'NULL'

	my $table = $field->dataset->get_sql_table_name;
	
	my $sql =
		"SELECT ".$self->quote_identifier( $field->get_sql_name ).
		" FROM ".$self->quote_identifier( $table ).
		" WHERE ".$self->quote_identifier( $field->get_sql_name )."=".$self->quote_value( $value )." COLLATE utf8_general_ci";

	my $sth = $self->prepare( $sql );
	$self->execute( $sth, $sql );

	my( $real_value ) = $sth->fetchrow_array;

	$sth->finish;

	return defined $real_value ? $real_value : $value;
}

sub duplicate_error { $DBI::err == 1062 }
sub retry_error { $DBI::err == 2006 }

sub type_info
{
	my( $self, $data_type ) = @_;

	if( $data_type eq SQL_CLOB )
	{
		return {
			TYPE_NAME => "longtext",
			CREATE_PARAMS => "",
			COLUMN_SIZE => 2 ** 31,
		};
	}
	else
	{
		return $self->SUPER::type_info( $data_type );
	}
}

# use MySQL 4.0 compatible "SHOW INDEX"
# This method gets the entire SHOW INDEX response and builds a look-up table of
# keys with their *ordered* columns. This ensures even if MySQL is weird and
# returns out of order results we won't break.
sub index_name
{
	my( $self, $table, @cols ) = @_;

	my $hash = sub { join ':', map { $self->quote_identifier( $_ ) } @_ }; 

	my $needle = &$hash( @cols );
	my %indexes;

	my $sth = $self->prepare("SHOW INDEX FROM ".$self->quote_identifier( $table ));
	$sth->execute;

	my( $key_name, $seq, $col_name );
	$sth->bind_col( $sth->{NAME_uc_hash}->{KEY_NAME} + 1, \$key_name );
	$sth->bind_col( $sth->{NAME_uc_hash}->{SEQ_IN_INDEX} + 1, \$seq );
	$sth->bind_col( $sth->{NAME_uc_hash}->{COLUMN_NAME} + 1, \$col_name );

	while($sth->fetch)
	{
		$indexes{$key_name} ||= [];
		$indexes{$key_name}[$seq - 1] = $col_name;
	}
	foreach $key_name (keys %indexes)
	{
		return $key_name if
			$needle eq &$hash( @{$indexes{$key_name}} );
	}

	return undef;
}

sub _create_table
{
	my( $self, $table, $primary_key, $columns ) = @_;

	my $sql = "";

	$sql .= "CREATE TABLE ".$self->quote_identifier($table)." (";
	$sql .= join(', ', @$columns);
	if( @$primary_key )
	{
		$sql .= ", PRIMARY KEY(".join(', ', map { $self->quote_identifier($_) } @$primary_key).")";
	}
	$sql .= ")";
	$sql .= " DEFAULT CHARSET=".$self->get_default_charset;
	
	my $engine = $self->{session}->config( "dbengine" );
	$sql .= " ENGINE=$engine" if $engine;

	return $self->do($sql);
}

1; # For use/require success

######################################################################
=pod

=back

=cut


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

