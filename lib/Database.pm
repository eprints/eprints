######################################################################
#
# EPrints Database Access Module
#
#  Provides access to the backend database. All database access done
#  via this module, in the hope that the backend can be replaced
#  as easily as possible.
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

package EPrints::Database;

use DBI;
use EPrintSite::SiteInfo;
use EPrints::Deletion;
use EPrints::EPrint;
use EPrints::Log;
use EPrints::MetaInfo;
use EPrints::Subscription;

use strict;

$EPrints::Database::driver = "DBI:mysql:";

#
# Table names
#
$EPrints::Database::table_counter = "counters";
$EPrints::Database::table_user = "users";
$EPrints::Database::table_inbox = "inbox";
$EPrints::Database::table_buffer = "buffer";
$EPrints::Database::table_archive = "archive";
$EPrints::Database::table_document = "documents";
$EPrints::Database::table_subject = "subjects";
$EPrints::Database::table_subscription = "subscriptions";
$EPrints::Database::table_deletion = "deletions";

#
# Counters
#
@EPrints::Database::counters = ( "eprintid" );

#
# Map of EPrints data types to MySQL types. keys %datatypes will give
#  a list of the types supported by the system.
#
%EPrints::Database::datatypes =
(
	"int"        => "INT UNSIGNED",
	"date"       => "DATE",
	"enum"       => "VARCHAR(255)",
	"boolean"    => "SET('TRUE','FALSE')",
	"set"        => "VARCHAR(255)",
	"text"       => "VARCHAR(255)",
	"multitext"  => "TEXT",
	"url"        => "VARCHAR(255)",
	"email"      => "VARCHAR(255)",
	"subjects"   => "TEXT",
	"username"   => "TEXT",
	"pagerange"  => "VARCHAR(255)",
	"year"       => "INT UNSIGNED",
	"multiurl"   => "TEXT",
	"eprinttype" => "VARCHAR(255)",
	"name"       => "VARCHAR(255)"
);

######################################################################
#
# build_connection_string()
#
#  Build the string to use to connect via DBI
#
######################################################################

sub build_connection_string
{
        # build the connection string
        my $dsn = $EPrints::Database::driver.
                "database=".$EPrintSite::SiteInfo::database;
        if (defined $EPrintSite::SiteInfo::db_host)
        {
                $dsn.= ";host=".$EPrintSite::SiteInfo::db_host;
        }
        if (defined $EPrintSite::SiteInfo::db_port)
        {
                $dsn.= ";port=".$EPrintSite::SiteInfo::db_port;
        }
        if (defined $EPrintSite::SiteInfo::db_socket)
        {
                $dsn.= ";mysql_socket=".$EPrintSite::SiteInfo::db_socket;
        }
        return $dsn;
}



######################################################################
#
# new()
#
#  Connect to the database.
#
######################################################################

sub new
{
	my( $class ) = @_;

	my $self = {};
	bless $self, $class;

	# Connect to the database
	$self->{dbh} = DBI->connect( &EPrints::Database::build_connection_string,
	                             $EPrintSite::SiteInfo::username,
	                             $EPrintSite::SiteInfo::password,
	                             { PrintError => 1, AutoCommit => 1 } );

#	                             { PrintError => 0, AutoCommit => 1 } );

	if( !defined $self->{dbh} )
	{
		return( undef );
	}

	#$self->{dbh}->trace( 2 );

	return( $self );
}



######################################################################
#
# disconnect()
#
#  Disconnects from the EPrints database. Should always be done
#  before any script exits.
#
######################################################################

sub disconnect
{
	my( $self ) = @_;
	
	# Make sure that we don't disconnect twice, or inappropriately
	if( defined $self->{dbh} )
	{
		$self->{dbh}->disconnect() ||
			EPrints::Log::log_entry( "Database", $self->{dbh}->errstr );
	}
}


######################################################################
#
# $error = error()
#
#  Gives details of any errors that have occurred
#
######################################################################

sub error
{
	my( $self ) = @_;
	
	return $self->{dbh}->errstr;
}


######################################################################
#
# $success = create_archive_tables()
#
#  Creates the archive tables (user, archive and buffer) from the
#  metadata tables.
#
######################################################################

sub create_archive_tables
{
	my( $self ) = @_;
	
	# Create the ID counter table
	my $success = $self->_create_counter_table();

	# Create the user table
	$success = $success && $self->_create_table(
		$EPrints::Database::table_user,
		EPrints::MetaInfo::get_user_fields() );
	

	# Document table
	$success = $success && $self->_create_table(
		$EPrints::Database::table_document,
		EPrints::MetaInfo::get_document_fields() );


	# EPrint tables
	my @eprint_metadata = EPrints::MetaInfo::get_all_eprint_fields();

	$success = $success && $self->_create_table(
		$EPrints::Database::table_inbox,
		@eprint_metadata );

	$success = $success && $self->_create_table(
		$EPrints::Database::table_buffer,
		@eprint_metadata );

	$success = $success && $self->_create_table(
		$EPrints::Database::table_archive,
		@eprint_metadata );


	# Subscription table
	$success = $success && $self->_create_table(
		$EPrints::Database::table_subscription,
		EPrints::MetaInfo::get_subscription_fields() );


	# Subject category table
	$success = $success && $self->_create_table(
		$EPrints::Database::table_subject,
		EPrints::MetaInfo::get_subject_fields() );

	# Deletion table
	$success = $success && $self->_create_table(
		$EPrints::Database::table_deletion,
		EPrints::MetaInfo::get_deletion_fields() );

	return( $success );
}
		


######################################################################
#
# $success = _create_table( $name, @fields )
#
#  Create a database table with the given name, and columns specified
#  in @fields, which is an array of MetaField types.
#
######################################################################

sub _create_table
{
	my( $self, $name, @fields ) = @_;
	
	my $field;

	# Construct the SQL statement
	my $sql = "CREATE TABLE $name (";
	my $key = undef;
	my @indices;

	# Iterate through the columns
	foreach $field (@fields)
	{
		$sql .= " $field->{name} $EPrints::Database::datatypes{$field->{type}}";

		if( !defined $key )
		{
			$key = $field->{name};
			$sql .= " NOT NULL";
		}
		elsif( $field->{indexed} )
		{
			$sql .= " NOT NULL";
			push @indices, $field->{name};
		}

		$sql .= ",";
	}
	
	$sql .= " PRIMARY KEY ($key)";
	
	foreach (@indices)
	{
		$sql .= ", INDEX($_)";
	}
	
	$sql .= ");";
	
#EPrints::Log::debug( "Database", "SQL: $sql" );

	# Send to the database
	my $rv = $self->{dbh}->do( $sql );
	
	# Return with an error if unsuccessful
	return( defined $rv );
}


######################################################################
#
# $success = add_record( $table, $data[][] )
#
#  Add data to the given table.
#
######################################################################

sub add_record
{
	my( $self, $table, $data ) = @_;
	
	my $sql = "INSERT INTO $table (";
	my $first = 1;
	my $i;
	
	foreach $i (@$data)
	{
		if( $first == 0 )
		{
			$sql .= ",";
		}
		else
		{
			$first=0;
		}

		$sql .= $i->[0];
	}

	$sql .= ") VALUES(";
	
	$first = 1;

	foreach $i (@$data)
	{
		if( $first == 0 )
		{
			$sql .= ",";
		}
		else
		{
			$first=0;
		}

		if( defined $i->[1] && $i->[1] ne "" )
		{
			$sql .= "\"$i->[1]\"" ;
		}
		else
		{
			$sql .= "NULL";
		}
	}

	$sql .= ");";	

#EPrints::Log::debug( "Database", "SQL: $sql" );

	# Send to the database
	my $rv = $self->{dbh}->do( $sql );
	
	# Return with an error if unsuccessful
	return( defined $rv );
}


######################################################################
#
# $success = update( $table, $key_field, $key_value, $data[][] )
#
#  Update the row where $key_field is $key_value, in $table, with
#  the given values.
#
######################################################################

sub update
{
	my( $self, $table, $key_field, $key_value, $data ) = @_;
	
	my $sql = "UPDATE $table SET ";
	my $column;
	my $first = 1;
	
	# Put the column data into the SQL statement
	foreach $column (@$data)
	{
		my @column_array = @$column;
		
		$sql .= "," unless $first;

		my $value;
		
		if( defined $column_array[1] )
		{
			$value = $column_array[1];
			# Convert \ to \\
			$value =~ s/\\/\\\\/g;
			# Convert " to \"
			$value =~ s/"/\\"/g;
			$value = "\"".$value."\"";
		}
		else
		{
			$value = "NULL";
		}

		$sql .= "$column_array[0]=$value";
		
		$first = 0;
	}

	$sql .= " WHERE $key_field LIKE \"$key_value\";";
	
#EPrints::Log::debug( "Database", "SQL: $sql" );

	# Send to the database
	my $rv = $self->{dbh}->do( $sql );
	
	# Return with an error if unsuccessful
	return( defined $rv );
}


######################################################################
#
# retrieve_single( $table, $key_field, $value )
#
#  Retrieves a single object from the database, where field 
#  $key_field matches $value. An empty list is returned if the field
#  can't be found.
#
######################################################################

sub retrieve_single
{
	my( $self, $table, $key_field, $value ) = @_;
	
	my $sql = "SELECT * FROM $table WHERE $key_field LIKE \"$value\";";

	my @row = $self->{dbh}->selectrow_array( $sql );

	return( @row );
}


######################################################################
#
# $rows = retrieve( $table, $cols[], $conditions[], $order )
#
#   Retrieve the specified rows from the $table, with the given
#   conditions. If conditions is undefined, retrieves all rows.
#   Returns a reference to an array of references to row arrays.
#   Erk! i.e.:
#
#   $rows = [  \@row1, \@row2, \@row3, ... ];
#
#   $order is a reference to an array specifying the order in which
#   rows should be returned. If undef, no order is imposed.
#
######################################################################

sub retrieve
{
	my( $self, $table, $cols, $conditions, $order ) = @_;

	my $sql = "SELECT ";

	$sql .= join( "," , @$cols );	
	$sql .= " FROM $table";

	if( defined $conditions )
	{
		$sql .= " WHERE ";
		$sql .= join( " \&\& " , @$conditions );	
	}

	if( defined $order )
	{
		$sql .= " ORDER BY ";
		$sql .= join( "," , @$order );	
	}		

	$sql .= ";";

#EPrints::Log::debug( "Database", "SQL:$sql" );
	my $ret_rows = $self->{dbh}->selectall_arrayref( $sql );

	return( $ret_rows );
}


######################################################################
#
# $rows = retrieve_fields( $table, $fields, $conditions, $order )
#
#  Convenience function. Similar to retrieve() above, except that
#  $fields should be an array of MetaField objects.
#
######################################################################

sub retrieve_fields
{
	my( $self, $table, $fields, $conditions, $order ) = @_;
	
	my @field_names;
	my $f;
	
	foreach $f (@$fields)
	{
		push @field_names, $f->{name};
	}

	my $rows = $self->retrieve( $table, \@field_names, $conditions, $order );

	return( $rows );
}


######################################################################
#
# $success = remove( $table, $field, $value )
#
#  Attempts to remove a record from $table, where $field=$value.
#  Typically, $field will be the key field and value the ID.
#
######################################################################

sub remove
{
	my( $self, $table, $field, $value ) = @_;
	
	my $sql = "DELETE FROM $table WHERE $field LIKE \"$value\";";

	my $rv = $self->{dbh}->do( $sql );

	# Return with an error if unsuccessful
	return( defined $rv )
}


######################################################################
#
# $success = _create_counter_table()
#
#  Creates the counter table.
#
######################################################################

sub _create_counter_table
{
	my( $self ) = @_;
	
	# The table creation SQL
	my $sql = "CREATE TABLE $EPrints::Database::table_counter ".
		"(countername VARCHAR(255) PRIMARY KEY, counter INT NOT NULL);";
	
	# Send to the database
	my $sth = $self->{dbh}->do( $sql );
	
	# Return with an error if unsuccessful
	return( 0 ) unless defined( $sth );

	# Create the counters
	foreach (@EPrints::Database::counters)
	{
		$sql = "INSERT INTO $EPrints::Database::table_counter VALUES ".
			"(\"$_\", 0);";

		$sth = $self->{dbh}->do( $sql );
		
		# Return with an error if unsuccessful
		return( 0 ) unless defined( $sth );
	}
	
	# Everything OK
	return( 1 );
}


######################################################################
#
# $count = counter_next( $counter )
#
#  Return the next value for the named counter. Returns undef if the
#  counter doesn't exist.
#
######################################################################

sub counter_next
{
	my( $self, $counter ) = @_;

	# Update the counter	
	my $sql = "UPDATE $EPrints::Database::table_counter SET counter=".
		"LAST_INSERT_ID(counter+1) WHERE countername LIKE \"$counter\";";
	
	# Send to the database
	my $rows_affected = $self->{dbh}->do( $sql );

	# Return with an error if unsuccessful
	return( undef ) unless( $rows_affected==1 );

	# Get the value of the counter
	$sql = "SELECT LAST_INSERT_ID();";
	my @row = $self->{dbh}->selectrow_array( $sql );

	return( $row[0] );
}


1; # For use/require success
