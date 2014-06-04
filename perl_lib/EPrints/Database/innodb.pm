######################################################################
#
# EPrints::Database::innodb
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
#  $self->{repository}
#     The EPrints::Session which is associated with this database 
#     connection.
#
#  $self->{dbh}
#     The handle on the actual database connection.
#
######################################################################

package EPrints::Database::innodb;

use EPrints;
use EPrints::Database qw( :sql_types );
use EPrints::Database::mysql;

@ISA = qw( EPrints::Database::mysql );

use strict;

# module to support InnoDB specifics:
#
# - transactions BEGIN, COMMIT, ROLLBACK - enabled via configuration
# - deleting/updating PK is done via the FK constraints so no need to do it here
# - set AutoCommit to FALSE if transactions are enabled
# - table LOCKS shouldn't be necessary right?


# TODO/sf2 - doesn't look like it's being called:
sub create
{
	my( $self, $username, $password ) = @_;
	
	my $repo = $self->{repository};

	my $transactional = $repo->config( "dbtransactions" ) || 0;

	my $dbh = DBI->connect( EPrints::Database::build_connection_string( 
			dbdriver => "mysql",
			dbhost => $repo->config("dbhost"),
			dbsock => $repo->config("dbsock"),
			dbport => $repo->config("dbport"),
			dbname => "mysql", ),
	        $username,
	        $password,
			{
				AutoCommit => !$transactional,
				RaiseError => 0,
				PrintError => 0,
			} );

	return undef if !defined $dbh;

	$dbh->{RaiseError} = 1;

	my $dbuser = $repo->config( "dbuser" );
	my $dbpass = $repo->config( "dbpass" );
	my $dbname = $repo->config( "dbname" );

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

=item $foo = $db->connect

Connects to the database. 

=cut
######################################################################

sub connect
{
	my( $self ) = @_;

	my $repo = $self->{repository};
	
	$self->{transactional} = $repo->config( "dbtransactions" ) || 0;

	if( $self->{transactional} )
	{
		$repo->debug_log( "db", "Database/InnoDB: transactions enabled" );;
	}

	# Connect to the database
	$self->{dbh} = DBI->connect_cached( 
			EPrints::Database::build_connection_string( 
				dbdriver => $repo->config("dbdriver"),
				dbhost => $repo->config("dbhost"),
				dbsock => $repo->config("dbsock"),
				dbport => $repo->config("dbport"),
				dbname => $repo->config("dbname"),
				dbsid => $repo->config("dbsid")
			),
			$repo->config("dbuser"),
			$repo->config("dbpass"),
			{
				AutoCommit => 1,
#				AutoCommit => !$self->{transactional},
			}
		);

	return unless defined $self->{dbh};	

	if( $repo->{noise} >= 4 )
	{
		$self->{dbh}->trace( 2 );
	}

	return 1;
}


######################################################################
=pod

=item $db->begin

Begin a transaction.

=cut
######################################################################

sub begin
{
	my( $self ) = @_;

	return if( !$self->{transactional} || $self->{".in-transaction"} );

	# Enable transactions (by turning AutoCommit off) until the next call to commit or rollback. After the next commit or rollback, AutoCommit will automatically be turned on again.
	if( !$self->{dbh}->begin_work )
	{
		$self->{repository}->log( 'begin_work failed' );
		return 0;
	}
	
	$self->{".in-transaction"} = 1;

	$self->{repository}->debug_log( "db", "transaction BEGIN" );
}

######################################################################
=pod

=item $db->commit

Commit the previous begun transaction.

=cut
######################################################################

sub commit
{
	my( $self ) = @_;
	
	return if( !$self->{transactional} );

	$self->{dbh}->commit;
	delete $self->{".in-transaction"};

	$self->{repository}->debug_log( "db", "transaction COMMIT" );
}

######################################################################
=pod

=item $db->rollback

Rollback the partially completed transaction.

=cut
######################################################################

sub rollback
{
	my( $self ) = @_;

	return if( !$self->{transactional} );

	$self->{dbh}->rollback;
	delete $self->{".in-transaction"};

	$self->{repository}->debug_log( "db", "transaction ROLLBACK" );
}

sub _update
{
	my( $self, $table, $keynames, $keyvalues, $columns, @values ) = @_;

	my $prefix = "UPDATE ".$self->quote_identifier($table)." SET ";
	my @where;
	for(my $i = 0; $i < @$keynames; ++$i)
	{
		push @where,
			$self->quote_identifier($keynames->[$i]).
			"=".
			$self->quote_value($keyvalues->[$i]);
	}
	my $postfix = "WHERE ".join(" AND ", @where);

	my $sql = $prefix;
	my $first = 1;
	for(@$columns)
	{
		$sql .= ", " unless $first;
		$first = 0;
		$sql .= $self->quote_identifier($_)."=?";
	}
	$sql .= " $postfix";

	my $sth = $self->prepare($sql);

	my $rv = 0;

	$self->begin;

	$self->{repository}->debug_log( "sql", $sql );
	
	foreach my $row (@values)
	{
		my $i = 0;
		for(@$row)
		{
			$sth->bind_param( ++$i, ref($_) eq 'ARRAY' ? @$_ : $_ );
		}
		my $rc = $sth->execute(); # execute can return "0e0"
		if( !$rc )
		{
			$self->{repository}->log( Carp::longmess( $sth->{Statement} . ": " . $self->{dbh}->err ) );
			return $rc;
		}
		$rv += $rc; # otherwise add up the number of rows affected
	}

	$sth->finish;

	$self->commit;

	return $rv == 0 ? "0e0" : $rv;
}

######################################################################
=pod

=item  $success = $db->_update_quoted( $tablename, $keycols, $keyvals, $columns, @qvalues )

UPDATES $tablename where $keycols equals $keyvals. Won't quote $keyvals or @qvalues before use - use this method with care!

This method is internal.

=cut
######################################################################

sub _update_quoted
{
	my( $self, $table, $keynames, $keyvalues, $columns, @values ) = @_;

	my $rc = 1;

	my $prefix = "UPDATE ".$self->quote_identifier($table)." SET ";
	my @where;
	for(my $i = 0; $i < @$keynames; ++$i)
	{
		push @where,
			$self->quote_identifier($keynames->[$i]).
			"=".
			$keyvalues->[$i];
	}
	my $postfix = "WHERE ".join(" AND ", @where);

	$self->begin;

	foreach my $row (@values)
	{
		my $sql = $prefix;
		for(my $i = 0; $i < @$columns; ++$i)
		{
			$sql .= ", " unless $i == 0;
			$sql .= $self->quote_identifier($columns->[$i])."=".$row->[$i];
		}
		$sql .= " $postfix";

		my $sth = $self->prepare($sql);
		$rc &&= $self->execute($sth, $sql);
		$sth->finish;
	}

	$self->commit;

	return $rc;
}

######################################################################
=pod

=item $success = $db->insert( $table, $columns, @values )

Inserts values into the table $table. If $columns is defined it will be used as
a list of columns to insert into. @values is a list of arrays containing values
to insert.

Values will be quoted before insertion.

=cut
######################################################################

sub insert
{
	my( $self, $table, $columns, @values ) = @_;

	my $rc = 1;

	my $sql = "INSERT INTO ".$self->quote_identifier($table);
	if( $columns )
	{
		$sql .= " (".join(",", map { $self->quote_identifier($_) } @$columns).")";
	}
	$sql .= " VALUES ";
	$sql .= "(".join(",", map { '?' } @$columns).")";

	$self->begin;
	$self->{repository}->debug_log( "sql", $sql );

	my $sth = $self->prepare($sql);
	foreach my $row (@values)
	{
		my $i = 0;
		for(@$row)
		{
			$sth->bind_param( ++$i, ref($_) eq 'ARRAY' ? @$_ : $_ );
		}
		$rc &&= $sth->execute();
	}
	
	# sf2 rollback if !$rc?
	$self->commit;

	return $rc;
}

######################################################################
=pod

=item $success = $db->insert_quoted( $table, $columns, @qvalues )

Inserts values into the table $table. If $columns is defined it will be used as
a list of columns to insert into. @qvalues is a list of arrays containing values
to insert.

Values will NOT be quoted before insertion - care must be exercised!

=cut
######################################################################

sub insert_quoted
{
	my( $self, $table, $columns, @values ) = @_;

	my $rc = 1;

	my $sql = "INSERT INTO ".$self->quote_identifier($table);
	if( $columns )
	{
		$sql .= " (".join(",", map { $self->quote_identifier($_) } @$columns).")";
	}
	$sql .= " VALUES ";

	$self->begin;
	
	$self->{repository}->debug_log( "sql", $sql );

	for(@values)
	{
		my $sql = $sql . "(".join(",", @$_).")";
		$rc &&= $self->do($sql);
	}

	$self->commit;

	return $rc;
}

######################################################################
=pod

=item $success = $db->delete_from( $table, $columns, @values )

Perform a SQL DELETE FROM $table using $columns to build a where clause.
@values is a list of array references of values in the same order as $columns.

If you want to clear a table completely use clear_table().

=cut
######################################################################

sub delete_from
{
	my( $self, $table, $keys, @values ) = @_;

	my $rc = 1;

	my $sql = "DELETE FROM ".$self->quote_identifier($table)." WHERE ".
		join(" AND ", map { $self->quote_identifier($_)."=?" } @$keys);

	$self->{repository}->debug_log( "sql", $sql );
	
	my $sth = $self->prepare($sql);
	for(@values)
	{
		$rc &&= $sth->execute( @$_ );
	}

	return $rc;
}

######################################################################
=pod

=item $success = $db->add_record( $dataset, $data )

Add the given data as a new record in the given dataset. $data is
a reference to a hash containing values structured for a record in
the that dataset.

=cut
######################################################################

sub add_record
{
	my( $self, $dataset, $data ) = @_;

	my $table = $dataset->get_sql_table_name();
	my $keyfield = $dataset->key_field();
	my $keyname = $keyfield->get_sql_name;
	my $id = $data->{$keyname};

	my $rc;

	{
		# local scope - add_record might be called from add_record

		$self->begin;
		my $transactional = $self->{transactional};
		local $self->{transactional} = 0;

		# atomically grab the slot in the table (key must be PRIMARY KEY!)
		{
			local $self->{dbh}->{PrintError};
			local $self->{dbh}->{RaiseError};
			if( !$self->insert( $table, [$keyname], [$id] ) )
			{
				Carp::carp( $DBI::errstr ) if !$self->duplicate_error;
				return 0;
			}
		}

		# Now add the ACTUAL data:
		$rc = $self->update( $dataset, $data, $data );	
		$self->{transactional} = $transactional;
		$self->commit;
	}

	return $rc;
}



######################################################################
=pod

=item $success = $db->update( $dataset, $data, $changed )

Updates a record in the database with the given $data. The key field value must be given.

Updates the ordervalues if the dataset is L<ordered|EPrints::DataSet/ordered>.

=cut
######################################################################

sub update
{
	my( $self, $dataset, $data, $changed ) = @_;

	my $rv = 1;

	my $keyfield = $dataset->key_field();
	my $keyname = $keyfield->get_sql_name();
	my $keyvalue = $data->{$keyname};

	my @aux;

	my @names;
	my @values;
	foreach my $fieldname ( keys %$changed )
	{
		next if $fieldname eq $keyname;
		my $field = $dataset->field( $fieldname );
		next if $field->is_virtual;
		# don't blank secret fields
		next if $field->isa( "EPrints::MetaField::Secret" ) && !EPrints::Utils::is_set( $data->{$fieldname} );

		if( $field->get_property( "multiple" ) )
		{
			push @aux, $field;
			next;
		}

		my $value = $data->{$fieldname};

		push @names, $field->get_sql_names;
		push @values, $field->sql_row_from_value( $self->{repository}, $value );
	}

	if( scalar @values )
	{
		$rv &&= $self->_update(
			$dataset->get_sql_table_name,
			[$keyname],
			[$keyvalue],
			\@names,
			\@values,
		);
	}

	# Erase old, and insert new, values into aux-tables.
	foreach my $multifield ( @aux )
	{
		my $auxtable = $dataset->get_sql_sub_table_name( $multifield );
		$rv &&= $self->delete_from( $auxtable, [$keyname], [$keyvalue] );

		my $values = $data->{$multifield->get_name()};

		# skip if there are no values at all
		if( !EPrints::Utils::is_set( $values ) )
		{
			next;
		}
		if( ref($values) ne "ARRAY" )
		{
			EPrints->abort( "Expected array reference for ".$multifield->get_name."\n".Data::Dumper::Dumper( $data ) );
		}

		my @names = ($keyname, "pos", $multifield->get_sql_names);
		my @rows;

		my $position=0;
		foreach my $value (@$values)
		{
			push @rows, [
				$keyvalue,
				$position++,
				$multifield->sql_row_from_value( $self->{repository}, $value )
			];
		}

		$rv &&= $self->insert( $auxtable, \@names, @rows );
	}

	return $rv;
}



######################################################################
=pod

=item $success = $db->remove( $dataset, $id )

Attempts to remove the record with the primary key $id from the 
specified dataset.

=cut
######################################################################

sub remove
{
	my( $self, $dataset, $id ) = @_;

	my $rv=1;

	my $keyfield = $dataset->key_field();
	my $keyname = $keyfield->get_sql_name();
	my $keyvalue = $id;

	# Note: unlike MyISAM, InnoDB supports foreign keys constraints and there are set by EPrints 
	# so the DB engine will delete the appropriate rows from the aux tables for us, we only
	# need to remove records from the main tables (eg. 'user')

	# Delete main table
	$rv &&= $self->delete_from(
		$dataset->get_sql_table_name,
		[$keyname],
		[$keyvalue]
	);

	if( !$rv )
	{
		$self->{repository}->log( "Error removing item id: $id" );
	}

	# Return with an error if unsuccessful
	return( defined $rv )
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

