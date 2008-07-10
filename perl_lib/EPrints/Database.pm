######################################################################
#
# EPrints::Database
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

B<EPrints::Database> - a connection to the SQL database for an eprints
session.

=head1 DESCRIPTION

EPrints Database Access Module

Provides access to the backend database. All database access done
via this module, in the hope that the backend can be replaced
as easily as possible.

The database object is created automatically when you start a new
eprints session. To get a handle on it use:

$db = $session->get_database

=head2 Cross-database Support

Any use of SQL must use quote_identifier to quote database tables and columns. The only exception to this are the Database::* modules which provide database-driver specific extensions.

Variables that are database quoted are prefixed with 'Q_'.

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

package EPrints::Database;

use DBI ();

use EPrints;

require Exporter;
@ISA = qw( Exporter );

use constant {
	SQL_NULL => 0,
	SQL_NOT_NULL => 1,
	SQL_VARCHAR => DBI::SQL_VARCHAR,
	SQL_LONGVARCHAR => DBI::SQL_LONGVARCHAR,
	SQL_VARBINARY => DBI::SQL_VARBINARY,
	SQL_LONGVARBINARY => DBI::SQL_LONGVARBINARY,
	SQL_TINYINT => DBI::SQL_TINYINT,
	SQL_SMALLINT => DBI::SQL_SMALLINT,
	SQL_INTEGER => DBI::SQL_INTEGER,
	SQL_REAL => DBI::SQL_REAL,
	SQL_DOUBLE => DBI::SQL_DOUBLE,
	SQL_DATE => DBI::SQL_DATE,
	SQL_TIME => DBI::SQL_TIME,
};

%EXPORT_TAGS = (
	sql_types => [qw(
		SQL_NULL
		SQL_NOT_NULL
		SQL_VARCHAR
		SQL_LONGVARCHAR
		SQL_VARBINARY
		SQL_LONGVARBINARY
		SQL_TINYINT
		SQL_SMALLINT
		SQL_INTEGER
		SQL_REAL
		SQL_DOUBLE
		SQL_DATE
		SQL_TIME
		)],
);
Exporter::export_tags( qw( sql_types ) );

use strict;
my $DEBUG_SQL = 0;

# this may not be the current version of eprints, it's the version
# of eprints where the current desired db configuration became standard.
$EPrints::Database::DBVersion = "3.1.1";

# cjg not using transactions so there is a (very small) chance of
# dupping on a counter. 

#
# Counters
#
@EPrints::Database::counters = ( 
	"cachemapid", 		"messageid", 
	"eprintid", 		"userid", 
	"savedsearchid",	"historyid",
	"accessid",		"requestid",
	"documentid",		"importid",
	"fileid",
);


# ID of next buffer table. This can safely reset to zero each time
# The module restarts as it is only used for temporary tables.
#
my $NEXTBUFFER = 0;
my %TEMPTABLES = ();

######################################################################
=pod

=item $dbstr = EPrints::Database::build_connection_string( %params )

Build the string to use to connect to the database via DBI. %params 
must contain dbname, and may also contain dbport, dbhost and dbsock.

=cut
######################################################################

sub build_connection_string
{
	my( %params ) = @_;

	$params{dbdriver} ||= "mysql";

        # build the connection string
        my $dsn = "DBI:$params{dbdriver}:";
		if( $params{dbdriver} eq "Oracle" )
		{
			$dsn .= "sid=$params{dbsid}";
		}
		else
		{
			$dsn .= "database=$params{dbname}";
		}
        if( defined $params{dbhost} )
        {
                $dsn.= ";host=".$params{dbhost};
        }
        if( defined $params{dbport} )
        {
                $dsn.= ";port=".$params{dbport};
        }
        if( defined $params{dbsock} )
        {
                $dsn.= ";mysql_socket=".$params{dbsock};
        }
        return $dsn;
}


######################################################################
=pod

=item $db = EPrints::Database->new( $session )

Create a connection to the database.

=cut
######################################################################

sub new
{
	my( $class , $session) = @_;

	my $driver = $session->get_repository->get_conf( "dbdriver" );
	$driver ||= "mysql";

	my $sub_class = "${class}::$driver";
	if( eval "use $sub_class; 1" )
	{
		$class = $sub_class;
	}
	die $@ if $@;

	my $self = {};
	bless $self, $class;
	$self->{session} = $session;
	Scalar::Util::weaken($self->{session})
		if defined &Scalar::Util::weaken;

	$self->connect;

	if( !defined $self->{dbh} ) { return( undef ); }

	$self->{debug} = $DEBUG_SQL;
	if( $session->{noise} == 3 )
	{
		$self->{debug} = 1;
	}


	return( $self );
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

	# Connect to the database
	$self->{dbh} = DBI->connect( 
		build_connection_string( 
			dbdriver => $self->{session}->get_repository->get_conf("dbdriver"),
			dbhost => $self->{session}->get_repository->get_conf("dbhost"),
			dbsock => $self->{session}->get_repository->get_conf("dbsock"),
			dbport => $self->{session}->get_repository->get_conf("dbport"),
			dbname => $self->{session}->get_repository->get_conf("dbname"),
			dbsid => $self->{session}->get_repository->get_conf("dbsid") ),
	        $self->{session}->get_repository->get_conf("dbuser"),
	        $self->{session}->get_repository->get_conf("dbpass") );

	return unless defined $self->{dbh};	

	if( $self->{session}->{noise} >= 4 )
	{
		$self->{dbh}->trace( 2 );
	}

	return 1;
}


######################################################################
=pod

=item $foo = $db->disconnect

Disconnects from the EPrints database. Should always be done
before any script exits.

=cut
######################################################################

sub disconnect
{
	my( $self ) = @_;
	# Make sure that we don't disconnect twice, or inappropriately
	if( defined $self->{dbh} )
	{
		$self->{dbh}->disconnect() ||
			$self->{session}->get_repository->log( "Database disconnect error: ".
				$self->{dbh}->errstr );
	}
	delete $self->{session};
}



######################################################################
=pod

=item $errstr = $db->error

Return a string describing the last SQL error.

=cut
######################################################################

sub error
{
	my( $self ) = @_;
	
	return $self->{dbh}->errstr;
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

	$self->{dbh}->{AutoCommit} = 0;
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

	return if $self->{dbh}->{AutoCommit};
	$self->{dbh}->commit;
	$self->{dbh}->{AutoCommit} = 1;
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

	return if $self->{dbh}->{AutoCommit};
	$self->{dbh}->rollback;
	$self->{dbh}->{AutoCommit} = 1;
}

######################################################################
=pod

=item $success = $db->create_archive_tables

Create all the SQL tables for each dataset.

=cut
######################################################################

sub create_archive_tables
{
	my( $self ) = @_;
	
	my $success = 1;

	foreach( &EPrints::DataSet::get_sql_dataset_ids )
	{
		$success = $success && $self->create_dataset_tables( 
			$self->{session}->get_repository->get_dataset( $_ ) );
	}

	$success = $success && $self->create_counters();

	$success = $success && $self->_create_index_queue_table();

	#$success = $success && $self->_create_permission_table();

	$self->create_version_table;	
	
	$self->set_version( $EPrints::Database::DBVersion );
	
	if( $success )
	{
		my $list = EPrints::DataObj::MetaField::load_all( $self->{session} );
		$success = $list->count > 0;
	}

	return( $success );
}
		

######################################################################
=pod

=item $success = $db->create_dataset_tables( $dataset )

Create all the SQL tables for a single dataset.

=cut
######################################################################


sub create_dataset_tables
{
	my( $self, $dataset ) = @_;
	
	my $rv = 1;

	if( $dataset->indexable )
	{
		$rv &&= $self->create_dataset_index_tables( $dataset );
	}

	$rv &&= $self->create_dataset_ordervalues_tables( $dataset );

	# Create the main tables
	if( !$self->has_table( $dataset->get_sql_table_name ) )
	{
		$rv &&= $self->create_table( 
				$dataset->get_sql_table_name, 
				$dataset, 
				1, 
				$dataset->get_fields( 1 ) );
	}

	return $rv;
}

######################################################################
=pod

=item $db->drop_dataset_tables( $dataset )

Drop all the SQL tables for a single dataset.

=cut
######################################################################

sub drop_dataset_tables
{
	my( $self, $dataset ) = @_;

	foreach my $field ($dataset->get_fields)
	{
		next if defined $field->get_property( "sub_name" );
		next unless $field->get_property( "multiple" );
		if( $self->{session}->get_noise >= 1 )
		{
			print "Removing ".$dataset->id.".".$field->get_name."\n";
		}
		$self->remove_field( $dataset, $field );
	}

	foreach my $langid ( @{$self->{session}->get_repository->get_conf( "languages" )} )
	{
		$self->drop_table( $dataset->get_ordervalues_table_name( $langid ) );
	}

	if( $self->{session}->get_noise >= 1 )
	{
		print "Removing ".$dataset->id."\n";
	}
	$self->drop_table( $dataset->get_sql_table_name );

	if( $dataset->indexable )
	{
		foreach(
			$dataset->get_sql_index_table_name,
			$dataset->get_sql_grep_table_name,
			$dataset->get_sql_rindex_table_name
		)
		{
			$self->drop_table( $_ );
		}
	}
}

######################################################################
=pod

=item $success = $db->create_dataset_index_tables( $dataset )

Create all the index tables for a single dataset.

=cut
######################################################################

sub create_dataset_index_tables
{
	my( $self, $dataset ) = @_;
	
	my $rv = 1;

	my $keyfield = $dataset->get_key_field()->clone;

	my $field_fieldword = EPrints::MetaField->new( 
		repository=> $self->{session}->get_repository,
		name => "fieldword", 
		type => "text");
	my $field_pos = EPrints::MetaField->new( 
		repository=> $self->{session}->get_repository,
		name => "pos", 
		type => "int" );
	my $field_ids = EPrints::MetaField->new( 
		repository=> $self->{session}->get_repository,
		name => "ids", 
		type => "longtext");
	if( !$self->has_table( $dataset->get_sql_index_table_name ) )
	{
		$rv &= $self->create_table(
			$dataset->get_sql_index_table_name,
			$dataset,
			0, # no primary key
			( $field_fieldword, $field_pos, $field_ids ) );
		$rv &= $self->add_index_to_indextable( $dataset );
	}

	#######################

		
	my $field_fieldname = EPrints::MetaField->new( 
		repository=> $self->{session}->get_repository,
		name => "fieldname", 
		type => "text" );
	my $field_grepstring = EPrints::MetaField->new( 
		repository=> $self->{session}->get_repository,
		name => "grepstring", 
		type => "text");

	if( !$self->has_table( $dataset->get_sql_grep_table_name ) )
	{
		$rv = $rv & $self->create_table(
			$dataset->get_sql_grep_table_name,
			$dataset,
			0, # no primary key
			( $keyfield, $field_fieldname, $field_grepstring ) );
	}


	return 0 unless $rv;
	###########################

	my $field_field = EPrints::MetaField->new( 
		repository=> $self->{session}->get_repository,
		name => "field", 
		type => "text" );
	my $field_word = EPrints::MetaField->new( 
		repository=> $self->{session}->get_repository,
		name => "word", 
		type => "text");

	if( !$self->has_table( $dataset->get_sql_rindex_table_name ) )
	{
		$rv = $rv & $self->create_table(
			$dataset->get_sql_rindex_table_name,
			$dataset,
			0, # no primary key
			( $keyfield, $field_field, $field_word ) );
	}



	return $rv;
}

sub add_index_to_indextable
{
	my( $self, $dataset ) = @_;

	my $table_name = $dataset->get_sql_index_table_name;

	return $self->create_index( $table_name, "fieldword", "pos" ) ? 1 : 0;
}
 
######################################################################
=pod

=item $success = $db->create_dataset_ordervalues_tables( $dataset )

Create all the ordervalues tables for a single dataset.

=cut
######################################################################

sub create_dataset_ordervalues_tables
{
	my( $self, $dataset ) = @_;
	
	my $rv = 1;

	my $keyfield = $dataset->get_key_field()->clone;
	# Create sort values table. These will be used when ordering search
	# results.
	my @fields = $dataset->get_fields( 1 );
	# remove the key field
	splice( @fields, 0, 1 ); 
	foreach my $langid ( @{$self->{session}->get_repository->get_conf( "languages" )} )
	{
		my $order_table = $dataset->get_ordervalues_table_name( $langid );
		my @orderfields = ( $keyfield );
		foreach my $field ( @fields )
		{
			push @orderfields, $field->create_ordervalues_field( $self->{session}, $langid );
		}

		if( !$self->has_table( $order_table ) )
		{
			$rv &&= $self->create_table( 
				$order_table,
				$dataset, 
				1, 
				@orderfields );
		}
	}

	return $rv;
}


# $db->get_ticket_userid( $code, $ip )
# 
# return the userid, if any, associated with the given ticket code and IP address.

sub get_ticket_userid
{
	my( $self, $code, $ip ) = @_;

	my $sql;

	my $Q_table = $self->quote_identifier( "loginticket" );
	my $Q_expires = $self->quote_identifier( "expires" );
	my $Q_userid = $self->quote_identifier( "userid" );
	my $Q_ip = $self->quote_identifier( "ip" );
	my $Q_code = $self->quote_identifier( "code" );

	# clean up old tickets
	$sql = "DELETE FROM $Q_table WHERE ".time." > $Q_expires";
	$self->do( $sql );

	$sql = "SELECT $Q_userid FROM $Q_table WHERE ($Q_ip='' OR $Q_ip=".$self->quote_value($ip).") AND $Q_code=".$self->quote_value($code);
	my $sth = $self->prepare( $sql );
	$self->execute( $sth , $sql );
	my( $userid ) = $sth->fetchrow_array;
	$sth->finish;

	return $userid;
}

sub update_ticket_userid
{
	my( $self, $code, $userid, $ip ) = @_;

	my $table = "loginticket";

	my $Q_table = $self->quote_identifier( $table );
	my $Q_userid = $self->quote_identifier( "userid" );
	my $Q_code = $self->quote_identifier( "code" );

	my $sql = "DELETE FROM $Q_table WHERE $Q_userid=".$self->quote_int($userid)." AND $Q_code=".$self->quote_value($code);
	$self->do($sql);

	$self->insert( $table, ["code","userid","ip","expires"], [
		$code,
		$userid,
		$ip,
		time()+60*60*24*7
	]);
}

######################################################################
=pod

=item $real_type = $db->get_column_type( NAME, TYPE, NOT_NULL, [ LENGTH/PRECISION ], [ SCALE ], %opts )

Returns a SQL column definition for NAME of type TYPE, usually something like:

	$name $type($length,$scale) [ NOT NULL ]

If NOT_NULL is true column will be set "not null".

LENGTH/PRECISION and SCALE control the maximum lengths of character or decimal types (see below).

Other options available to refine the column definition:

	langid - character set/collation to use
	sorted - whether this column will be used to order by

B<langid> is mapped to real database values by the "dblanguages" configuration option. The database may not be able to order the request column type in which case, if B<sorted> is true, the database may use a substitute column type.

TYPE is the SQL type. The types are constants defined by this module, to import them use:

  use EPrints::Database qw( :sql_types );

Supported types (n = requires LENGTH argument):

Character data: SQL_VARCHAR(n), SQL_LONGVARCHAR.

Binary data: SQL_VARBINARY(n), SQL_LONGVARBINARY.

Integer data: SQL_TINYINT, SQL_SMALLINT, SQL_INTEGER.

Floating-point data: SQL_REAL, SQL_DOUBLE.

Time data: SQL_DATE, SQL_TIME.

The actual column types used will be database-specific.

=cut
######################################################################

sub get_column_type
{
	my( $self, $name, $data_type, $not_null, $length, $scale, %opts ) = @_;

	my $session = $self->{session};
	my $repository = $session->get_repository;

	my $type_info = $self->{dbh}->type_info( $data_type );

	my $db_type = $type_info->{TYPE_NAME};
	my $params = $type_info->{CREATE_PARAMS};

	my $type = $self->quote_identifier($name) . " " . $db_type;

	$params ||= "";
	if( $params eq "max length" )
	{
		EPrints::abort( "get_sql_type expected LENGTH argument for $data_type [$type]" )
			unless defined $length;
		$type .= "($length)";
	}
	elsif( $params eq "precision,scale" )
	{
		EPrints::abort( "get_sql_type expected PRECISION and SCALE arguments for $data_type [$type]" )
			unless defined $scale;
		$type .= "($length,$scale)";
	}

	if( $opts{langid} )
	{
		my $conf = $repository->get_conf( "dblanguages", $opts{langid} );

		if( defined( $conf ) && defined( $conf->{charset} ) )
		{
			$type .= " CHARACTER SET ".$conf->{charset};
			if( defined( $conf->{collate} ) )
			{
				$type .= " COLLATE ".$conf->{collate};
			}
		}
	}

	if( $not_null )
	{
		$type .= " NOT NULL";
	}

	return $type;
}

######################################################################
=pod

=item  $success = $db->create_table( $tablename, $dataset, $setkey, @fields );

Create the tables used to store metadata for this dataset: the main
table and any required for multiple or mulitlang fields.

=cut
######################################################################

sub create_table
{
	my( $self, $tablename, $dataset, $setkey, @fields ) = @_;
	
	my $field;
	my $rv = 1;


	# build the sub-tables first
	foreach $field (@fields)
	{
		next unless ( $field->get_property( "multiple" ) );
		next if( $field->is_virtual );
		# make an aux. table for a multiple field
		# which will contain the same type as the
		# key of this table paired with the non-
		# multiple version of this field.
		# auxfield and keyfield must be indexed or 
		# there's not much point. 

		my $auxfield = $field->clone;
		$auxfield->set_property( "multiple", 0 );
		my $keyfield = $dataset->get_key_field()->clone;
#print $field->get_name()."\n";
#foreach( keys %{$auxfield} ) { print "* $_ => ".$auxfield->{$_}."\n"; }
#print "\n\n";

		# cjg Hmmmm
		#  Multiple ->
		# [key] [cnt] [field]
		#  Lang ->
		# [key] [lang] [field]
		#  Multiple + Lang ->
		# [key] [pos] [lang] [field]

		my @auxfields = ( $keyfield );
		if ( $field->get_property( "multiple" ) )
		{
			my $pos = EPrints::MetaField->new( 
				repository=> $self->{session}->get_repository,
				name => "pos", 
				type => "int" );
			push @auxfields,$pos;
		}
		push @auxfields,$auxfield;
		my $rv = $rv && $self->create_table(	
			$dataset->get_sql_sub_table_name( $field ),
			$dataset,
			2, # use key + pos as primary key
			@auxfields );
	}

	# Construct the SQL statement
	my $key = undef;
	my @indices;
	my @columns;
	foreach $field (@fields)
	{
		next if( $field->get_property( "multiple" ) );
		next if( $field->is_virtual );

		my $notnull = 0;
			
		# First field is primary key.
		if( !defined $key && $setkey)
		{
			$key = $field;
			$notnull = 1;
		}
		else
		{
			my @index_columns = $field->get_sql_index();
			if( scalar @index_columns )
			{
				push @indices, \@index_columns;
			}
		}
		push @columns, $field->get_sql_type( $self->{session}, $notnull );

	}
	my @primary_key;
	if( $setkey )	
	{
		if( $setkey == 2 )	
		{
			push @primary_key, $key->get_sql_name(), "pos";
		}
		else
		{
			push @primary_key, $key->get_sql_name();
		}
	}

	
	# Send to the database
	$rv = $rv && $self->_create_table( $tablename, \@primary_key, \@columns );
	
	my $idx = 1;
	foreach (@indices)
	{
		$rv &&= $self->create_index( $tablename, @$_ );
	}
	
	# Return with an error if unsuccessful
	return( defined $rv );
}

sub _create_table
{
	my( $self, $table, $primary_key, $columns ) = @_;

	my $sql;

	$sql .= "CREATE TABLE ".$self->quote_identifier($table)." (";
	$sql .= join(', ', @$columns);
	if( @$primary_key )
	{
		$sql .= ", PRIMARY KEY(".join(', ', map { $self->quote_identifier($_) } @$primary_key).")";
	}
	$sql .= ")";

	return $self->do($sql);
}

######################################################################
=pod

=item $boolean = $db->has_sequence( $name )

Return true if a sequence of the given name exists in the database.

=cut
######################################################################

sub has_sequence
{
	my( $self, $name ) = @_;

	return 0;
}

######################################################################
=pod

=item  $success = $db->create_sequence( $seq_name )

Creates a new sequence object initialised to zero.

=cut
######################################################################

sub create_sequence
{
	my( $self, $name ) = @_;

	my $rc = 1;

	$self->drop_sequence( $name );

	my $sql = "CREATE SEQUENCE ".$self->quote_identifier($name)." " .
		"INCREMENT BY 1 " .
		"MINVALUE 0 " .
		"MAXVALUE 999999999999999999999999999 " .
		"START WITH 1 ";

	$rc &&= $self->do($sql);

	return $rc;
}

######################################################################
=pod

=item  $success = $db->drop_sequence( $seq_name )

Deletes a sequence object.

=cut
######################################################################

sub drop_sequence
{
	my( $self, $name ) = @_;

	if( $self->has_sequence( $name ) )
	{
		$self->do("DROP SEQUENCE ".$self->quote_identifier($name));
	}
}

######################################################################
=pod

=item @columns = $db->get_primary_key( $tablename )

Returns the list of column names that comprise the primary key for $tablename.

Returns empty list if no primary key exists.

=cut
######################################################################

sub get_primary_key
{
	my( $self, $tablename ) = @_;

	return $self->{dbh}->primary_key( undef, undef, $tablename );
}

######################################################################
=pod

=item  $success = $db->create_index( $tablename, @columns )

Creates an index over @columns for $tablename. Returns true on success.

=cut
######################################################################

sub create_index
{
	my( $self, $table, @columns ) = @_;

	return 1 unless @columns;

	# Oracle maxes out at 30 chars, any other offers?
	my $index_name = join("_",$table,@columns);
	$index_name =~ s/^(.{15}).*(.{15})/$1$2/;

	my $sql = "CREATE INDEX $index_name ON ".$self->quote_identifier($table)."(".join(',',map { $self->quote_identifier($_) } @columns).")";

	return $self->do($sql);
}

######################################################################
=pod

=item  $success = $db->create_unique_index( $tablename, @columns )

Creates a unique index over @columns for $tablename. Returns true on success.

=cut
######################################################################

sub create_unique_index
{
	my( $self, $table, @columns ) = @_;

	return 1 unless @columns;

	# MySQL max index name length is 64 chars
	my $index_name = substr(join("_",$table,@columns),0,63);

	my $sql = "CREATE UNIQUE INDEX $index_name ON $table(".join(',',map { $self->quote_identifier($_) } @columns).")";

	return $self->do($sql);
}

######################################################################
=pod

=item  $success = $db->_update( $tablename, $keycols, $keyvals, $columns, @values )

UPDATES $tablename where $keycols equals $keyvals.

This method is internal.

=cut
######################################################################

sub _update
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

	if( $self->{debug} )
	{
		$self->{session}->get_repository->log( "Database execute debug: $sql" );
	}

	for(@values)
	{
		$rc &&= $sth->execute(@$_);
	}

	$sth->finish;

	return $rc;
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

	if( $self->{debug} )
	{
		$self->{session}->get_repository->log( "Database execute debug: $sql" );
	}

	my $sth = $self->prepare($sql);
	for(@values)
	{
		$rc &&= $sth->execute( @$_ );
	}

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

	for(@values)
	{
		my $sql = $sql . "(".join(",", @$_).")";
		$rc &&= $self->do($sql);
	}

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
	my $keyfield = $dataset->get_key_field();
	my $kf_sql = $keyfield->get_sql_name;
	my $id = $data->{$kf_sql};

	if( $self->exists( $dataset, $id ) )
	{
		# item already exists.
		$self->{session}->get_repository->log( 
"Failed in attempt to create existing item $id in table $table." );
		return 0;
	}

	# Now add the ACTUAL data:
	my $rv = $self->update( $dataset , $data, 1 );
	
	# Return with an error if unsuccessful
	return( defined $rv );
}


######################################################################
=pod

=item $mungedvalue = EPrints::Database::prep_int( $value )

Escape a numerical value for SQL. undef becomes NULL. Anything else
becomes a number (zero if needed).

=cut
######################################################################

sub prep_int
{
	my( $value ) = @_; 

	return "NULL" unless( defined $value );

	return $value+0;
}

######################################################################
=pod

=item $mungedvalue = EPrints::Database::prep_value( $value )

Escape a value for SQL. Modify value such that " becomes \" and \ 
becomes \\ and ' becomes \'

=cut
######################################################################

sub prep_value
{
	my( $value ) = @_; 
	
	return "" unless( defined $value );
	$value =~ s/["\\']/\\$&/g;
	return $value;
}


######################################################################
=pod

=item $mungedvalue = EPrints::Database::prep_like_value( $value )

Escape an value for an SQL like field. In addition to ' " and \ also 
escapes % and _

=cut
######################################################################

sub prep_like_value
{
	my( $value ) = @_; 
	
	return "" unless( defined $value );
	$value =~ s/["\\'%_]/\\$&/g;
	return $value;
}

######################################################################
=pod

=item $str = $db->quote_value( $value )

Return a quoted value. To quote a 'like' value you should do:

 my $str = $database->quote_value( EPrints::Database::prep_like_value( $foo ) . '%' );

=cut
######################################################################

sub quote_value
{
	my( $self, $value ) = @_;

	return $self->{dbh}->quote( $value );
}

######################################################################
=pod

=item $str = $db->quote_int( $value )

Return a quoted integer value

=cut
######################################################################

sub quote_int
{
	my( $self, $value ) = @_;

	return "NULL" unless( defined $value );

	return $value+0;
}

######################################################################
=pod

=item $str = $db->quote_identifier( @parts )

Quote a database identifier (e.g. table names). Multiple @parts will be joined
by dot.

=cut
######################################################################

sub quote_identifier
{
	my( $self, @parts ) = @_;

	return join('.',map { $self->{dbh}->quote_identifier($_) } @parts);
}

######################################################################
=pod

=item $success = $db->update( $dataset, $data, $insert )

Updates a record in the database with the given $data. Obviously the
value of the primary key must be set.

This also updates the text indexes and the ordering keys.

=cut
######################################################################

sub update
{
	my( $self, $dataset, $data, $insert ) = @_;

	my $rv = 1;
	my @fields = $dataset->get_fields( 1 );

	my $keyfield = $dataset->get_key_field();
	my $keyname = $keyfield->get_sql_name();
	my $keyvalue = $data->{$keyname};

	my @names;
	my @values;

	my @aux;
	my $field;
	foreach $field ( @fields ) 
	{
		next if( $field->is_virtual );

		if( $field->is_type( "secret" ) &&
			!EPrints::Utils::is_set( $data->{$field->get_name()} ) )
		{
			# No way to blank a secret field, as a null value
			# is totally skipped when updating.
			next;
		}

		if( $field->get_property( "multiple" ) )
		{ 
			push @aux,$field;
			next;
		}
	
		my $value = $data->{$field->get_name()};
		# clearout the freetext search index table for this field.

		push @names, $field->get_sql_names;
		push @values, $field->sql_row_from_value( $self->{session}, $value );
	}
	
	if( $insert )
	{
		$self->insert(
			$dataset->get_sql_table_name,
			\@names,
			\@values,
		);
	}
	else
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
		if( !$insert )
		{
			$rv &&= $self->delete_from( $auxtable, [$keyname], [$keyvalue] );
		}

		# skip to next table if there are no values at all for this
		# one.
		if( !EPrints::Utils::is_set( $data->{$multifield->get_name()} ) )
		{
			next;
		}

		my $fieldvalue = $data->{$multifield->get_name()};

		my @names = ($keyname, "pos");
		push @names, $multifield->get_sql_names;

		my @rows;

		my $position=0;
		foreach my $value (@$fieldvalue)
		{
			my @values = (
				$keyvalue,
				$position++,
				$multifield->sql_row_from_value( $self->{session}, $value )
			);
			push @rows, \@values;
		}

		$rv &&= $self->insert( $auxtable, \@names, @rows );
	}

	if( $insert )
	{
		EPrints::Index::insert_ordervalues( $self->{session}, $dataset, $data );
	}
	else
	{
		EPrints::Index::update_ordervalues( $self->{session}, $dataset, $data );
	}

	# Return with an error if unsuccessful
	return( defined $rv );
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

	my $keyfield = $dataset->get_key_field();
	my $keyname = $keyfield->get_sql_name();
	my $keyvalue = $id;

	# Delete from index (no longer used)
	#$self->_deindex( $dataset, $id );

	# Delete Subtables
	my @fields = $dataset->get_fields( 1 );
	foreach my $field ( @fields ) 
	{
		next unless( $field->get_property( "multiple" ) );
		# ideally this would actually remove the subobjects
		next if( $field->is_virtual );
		my $auxtable = $dataset->get_sql_sub_table_name( $field );
		$rv &&= $self->delete_from(
			$auxtable,
			[$keyname],
			[$keyvalue]
		);
	}

	# Delete main table
	$rv &&= $self->delete_from(
		$dataset->get_sql_table_name,
		[$keyname],
		[$keyvalue]
	);

	if( !$rv )
	{
		$self->{session}->get_repository->log( "Error removing item id: $id" );
	}

	EPrints::Index::delete_ordervalues( $self->{session}, $dataset, $id );

	# Return with an error if unsuccessful
	return( defined $rv )
}


######################################################################
=pod

=item $success = $db->create_counters

Create the counters used to store the highest current id of eprints,
users etc.

=cut
######################################################################

sub create_counters
{
	my( $self ) = @_;

	my $rc = 1;

	# Create the counters 
	foreach my $counter (@EPrints::Database::counters)
	{
		$rc &&= $self->create_counter( $counter );
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

	return $self->has_sequence( $name . "_seq" );
}

######################################################################
=pod

=item $success = $db->create_counter( $name )

Create and initialise to zero a new counter called $name.

=cut
######################################################################

sub create_counter
{
	my( $self, $name ) = @_;

	return $self->create_sequence( $name . "_seq" );
}

######################################################################
=pod

=item $success = $db->remove_counters

Destroy all counters.

=cut
######################################################################

sub remove_counters
{
	my( $self ) = @_;

	foreach my $counter (@EPrints::Database::counters)
	{
		$self->drop_counter( $counter );
	}
}

######################################################################
=pod

=item $success = $db->drop_counter( $name )

Destroy the counter named $name.

=cut
######################################################################

sub drop_counter
{
	my( $self, $name ) = @_;

	$self->drop_sequence( $name . "_seq" );
}

sub save_user_message
{
	my( $self, $userid, $m_type, $dom_m_data ) = @_;

	my $dataset = $self->{session}->get_repository->get_dataset( "message" );

	my $message = $dataset->create_object( $self->{session}, {
		userid => $userid,
		type => $m_type,
		message => EPrints::XML::to_string($dom_m_data)
	});

	return $message;
}

sub get_user_messages
{
	my( $self, $userid ) = @_;

	my $dataset = $self->{session}->get_repository->get_dataset( "message" );

	my $searchexp = EPrints::Search->new(
		satisfy_all => 1,
		session => $self->{session},
		dataset => $dataset,
		custom_order => $dataset->get_key_field->get_name,
	);

	$searchexp->add_field( $dataset->get_field( "userid" ), $userid );

	my $results = $searchexp->perform_search;

	my @messages;

	my $fn = sub {
		my( $session, $dataset, $message, $messages ) = @_;
		my $msg = $message->get_value( "message" );
		my $content;
		eval {
			my $doc = EPrints::XML::parse_xml_string( "<div>$msg</div>" );
			if( EPrints::XML::is_dom( $doc, "Document" ) )
			{
				$content = $session->clone_for_me($doc->getDocumentElement,1);
			}	
			else
			{
				$content = $session->clone_for_me($doc,1);
			}	
			EPrints::XML::dispose($doc);
		};
		if( !$content )
		{
			$content = $session->make_element( "div" );
			$content->appendChild( $session->make_text( "Internal error while parsing: $msg" ));
		}
		push @$messages, {
			type => $message->get_value( "type" ),
			content => $content,
		};
	};
	$results->map( $fn, \@messages );

	return @messages;
}

sub clear_user_messages
{
	my( $self, $userid ) = @_;

	my $dataset = $self->{session}->get_repository->get_dataset( "message" );

	my $searchexp = EPrints::Search->new(
		satisfy_all => 1,
		session => $self->{session},
		dataset => $dataset,
	);

	$searchexp->add_field( $dataset->get_field( "userid" ), $userid );

	my $results = $searchexp->perform_search;

	my $fn = sub {
		my( $session, $dataset, $message ) = @_;
		$message->remove;
	};
	$results->map( $fn, undef );
}

######################################################################
# 
# $success = $db->_create_index_queue_table
#
# create the table used to keep track of what needs to be indexed in
# this repository.
#
######################################################################

sub _create_index_queue_table
{
	my( $self ) = @_;

	my $rc = 1;

	# The table creation SQL
	$rc &&= $self->_create_table("index_queue", [], [
		$self->get_column_type( "field", SQL_VARCHAR, SQL_NULL, 128 ),
		$self->get_column_type( "added", SQL_TIME ),
	]);
	$rc &&= $self->create_index( "index_queue", "field" );
	$rc &&= $self->create_index( "index_queue", "added" );

	return $rc;
}

######################################################################
# 
# $success = $db->_create_permission_table
#
# create the tables needed to store the permissions. 
#
######################################################################

sub _create_permission_table
{
	my( $self ) = @_;

	my $rc = 1;

	$rc &&= $self->_create_table("permission", ["role","privilege"], [
		$self->get_column_type( "role", SQL_VARCHAR, SQL_NOT_NULL, 64 ),
		$self->get_column_type( "privilege", SQL_VARCHAR, SQL_NOT_NULL, 64),
		$self->get_column_type( "net_from", SQL_INTEGER ),
		$self->get_column_type( "net_to", SQL_INTEGER ),
	]);
	$rc &&= $self->create_unique_index( "permission", "privilege", "role" );

	$rc &&= $self->_create_table("permission_group", ["user","role"], [
		$self->get_column_type( "user", SQL_VARCHAR, SQL_NOT_NULL, 64),
		$self->get_column_type( "role", SQL_VARCHAR, SQL_NOT_NULL, 64),
	]);

	return $rc;
}

#

######################################################################
=pod

=item $n = $db->next_doc_pos( $eprintid )

Return the next unused document pos for the given eprintid.

=cut
######################################################################

sub next_doc_pos
{
	my( $self, $eprintid ) = @_;

	if( $eprintid ne $eprintid + 0 )
	{
		EPrints::abort( "next_doc_pos got odd eprintid: '$eprintid'" );
	}

	my $Q_table = $self->quote_identifier( "document" );
	my $Q_eprintid = $self->quote_identifier( "eprintid" );
	my $Q_pos = $self->quote_identifier( "pos" );

	my $sql = "SELECT MAX($Q_pos) FROM $Q_table WHERE $Q_eprintid=$eprintid";
	my @row = $self->{dbh}->selectrow_array( $sql );
	my $max = $row[0] || 0;

	return $max + 1;
}

######################################################################
=pod

=item $n = $db->counter_current( $counter )

Return the value of the previous counter_next on $counter.

=cut
######################################################################

sub counter_current
{
	my( $self, $counter ) = @_;

	$counter .= "_seq";

	my $sql = "SELECT ".$self->quote_identifier($counter).".currval FROM dual";

	my $sth = $self->prepare( $sql );
	$self->execute( $sth, $sql );

	my( $id ) = $sth->fetchrow_array;

	return $id + 0;
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

	$counter .= "_seq";

	my $sql = "SELECT ".$self->quote_identifier($counter).".nextval FROM dual";

	my $sth = $self->prepare($sql);
	$self->execute( $sth, $sql );

	my( $id ) = $sth->fetchrow_array;

	return $id + 0;
}

######################################################################
=pod

=item $db->counter_minimum( $counter, $value )

Ensure that the counter is set no lower than $value. This is used when
importing eprints which may not be in scrict sequence.

=cut
######################################################################

sub counter_minimum
{
	my( $self, $counter, $value ) = @_;

	$value+=0; # ensure numeric!

	my $counter_seq = $counter . "_seq";

	my $curval = $self->counter_current( $counter );
	# If .next() hasn't been called .current() will be undefined/0
	if( !$curval )
	{
		$self->counter_next( $counter );
	}

	if( $curval < $value )
	{
		$self->do("ALTER SEQUENCE ".$self->quote_identifier($counter_seq)." INCREMENT BY ".($value-$curval-1));
		$curval = $self->counter_next( $counter );
		$self->do("ALTER SEQUENCE ".$self->quote_identifier($counter_seq)." INCREMENT BY 1");
	}

	return $curval + 0;
}


######################################################################
=pod

=item $db->counter_reset( $counter )

Reset the counter. Use with caution.

=cut
######################################################################

sub counter_reset
{
	my( $self, $counter ) = @_;

	my $counter_seq = $counter . "_seq";

	my $curval = $self->counter_next( $counter );

	$self->do("ALTER SEQUENCE ".$self->quote_identifier($counter_seq)." INCREMENT BY ".(-1*$curval)." MINVALUE 0");
	$curval = $self->counter_next( $counter );
	$self->do("ALTER SEQUENCE ".$self->quote_identifier($counter_seq)." INCREMENT BY 1 MINVALUE 0");

	return $curval + 0;
}

# Internal method to get a cache object
sub get_cachemap
{
	my( $self, $id ) = @_;

	return $self->{session}->get_repository->get_dataset( "cachemap" )->get_object( $self->{session}, $id );
}

######################################################################
=pod

=item $searchexp = $db->cache_exp( $cacheid )

Return the serialised Search of a the cached search with
id $cacheid. Return undef if the id is invalid or expired.

=cut
######################################################################

sub cache_exp
{
	my( $self , $id ) = @_;

	my $a = $self->{session}->get_repository;
	my $cache = $self->get_cachemap( $id );

	return unless $cache;

	my $created = $cache->get_value( "created" );
	if( (time() - $created) > ($a->get_conf("cache_maxlife") * 3600) )
	{
		return;
	}

	return $cache->get_value( "searchexp" );
}

sub cache_userid
{
	my( $self , $id ) = @_;

	my $cache = $self->get_cachemap( $id );

	return defined( $cache ) ? $cache->get_value( "userid" ) : undef;
}

######################################################################
=pod

=item $cacheid = $db->cache( $searchexp, $dataset, $srctable, [$order], [$list] )

Create a cache of the specified search expression from the SQL table
$srctable.

If $order is set then the cache is ordered by the specified fields. For
example "-year/title" orders by year (descending). Records with the same
year are ordered by title.

If $srctable is set to "LIST" then order is ignored and the list of
ids is taken from the array reference $list.

If $srctable is set to "ALL" every matching record from $dataset is added to
the cache, optionally ordered by $order.

=cut
######################################################################

sub cache
{
	my( $self , $code , $dataset , $srctable , $order, $list ) = @_;

	# nb. all caches are now oneshot.
	my $userid = undef;
	my $user = $self->{session}->current_user;
	if( defined $user )
	{
		$userid = $user->get_id;
	}

	my $ds = $self->{session}->get_repository->get_dataset( "cachemap" );
	my $cachemap = $ds->create_object( $self->{session}, {
		lastused => time(),
		userid => $userid,
		searchexp => $code,
		oneshot => "TRUE",
	});
	
	my $cache_table  = $cachemap->get_sql_table_name;
	my $keyfield = $dataset->get_key_field();

	$self->_create_table( $cache_table, ["pos"], [
			$self->get_column_type( "pos", SQL_INTEGER, SQL_NOT_NULL ),
			$keyfield->get_sql_type( $self->{session}, 1 ),
			]);

	if( $srctable eq "NONE" )
	{
		# Leave the table empty
	}
	elsif( $srctable eq "ALL" )
	{
		my $logic = [];
		$srctable = $dataset->get_sql_table_name;
		if( $dataset->get_dataset_id_field )
		{
			push @$logic, $self->quote_identifier( $dataset->get_dataset_id_field ) . "=" . $self->quote_value( $dataset->id );
		}
		$self->_cache_from_TABLE($cachemap, $dataset, $srctable, $order, $list, $logic );
	}
	elsif( $srctable eq "LIST" )
	{
		$self->_cache_from_LIST($cachemap, @_[2..$#_]);
	}
	else
	{
		$self->_cache_from_TABLE($cachemap, @_[2..$#_]);
	}

	return $cachemap->get_id;
}

sub _cache_from_LIST
{
	my( $self, $cachemap, $dataset, $srctable, $order, $list ) = @_;

	my $cache_table  = $cachemap->get_sql_table_name;

	my $sth = $self->prepare( "INSERT INTO ".$self->quote_identifier($cache_table)." VALUES (?,?)" );
	my $i = 0;
	foreach( @{$list} )
	{
		$sth->execute( ++$i, $_ );
	}
}

sub _cache_from_TABLE
{
	my( $self, $cachemap, $dataset, $srctable, $order, $logic ) = @_;

	my $cache_table  = $cachemap->get_sql_table_name;
	my $cache_seq = $cache_table . "_seq";
	my $cache_trigger = $cache_table . "_trig";
	my $keyfield = $dataset->get_key_field();
	$logic ||= [];

	my $Q_cache_table = $self->quote_identifier( $cache_table );
	my $Q_trigger = $self->quote_identifier( $cache_trigger );
	my $NEXTVAL = $self->quote_identifier($cache_seq).".nextval";
	my $Q_keyname = $self->quote_identifier($keyfield->get_name());
	my $B = $self->quote_identifier("B");
	my $O = $self->quote_identifier("O");
	my $Q_srctable = $self->quote_identifier($srctable);

	$self->create_sequence( $cache_seq );

	my $sql = <<EOT;
CREATE OR REPLACE TRIGGER $Q_trigger
  BEFORE INSERT ON $Q_cache_table
  FOR EACH ROW
BEGIN
  SELECT $NEXTVAL INTO :new."pos" FROM dual;
END;
EOT
	$self->do($sql);

	$sql = "INSERT INTO $Q_cache_table ($Q_keyname) SELECT $B.$Q_keyname FROM $Q_srctable $B";
	if( defined $order )
	{
		$sql .= " LEFT JOIN ".$self->quote_identifier($dataset->get_ordervalues_table_name($self->{session}->get_langid()))." $O";
		$sql .= " ON $B.$Q_keyname = $O.$Q_keyname";
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
			$sql .= "$O.".$self->quote_identifier($field->get_sql_name());
			$sql .= " DESC" if $desc;
			$first = 0;
		}
	}
	$self->do( $sql );

	$self->drop_sequence( $cache_seq );

	$self->do("DROP TRIGGER $Q_trigger");
}


######################################################################
=pod

=item $tablename = $db->cache_table( $id )

Return the SQL table used to store the cache with id $id.

=cut
######################################################################

sub cache_table
{
	my( $self, $id ) = @_;

	return "cache".$id;
}

######################################################################
=pod

=item $ids = $db->get_index_ids( $table, $condition )

Return a reference to an array of the distinct primary keys from the
given SQL table which match the specified condition.

=cut
######################################################################

sub get_index_ids
{
	my( $self, $table, $condition ) = @_;

	my $Q_table = $self->quote_identifier($table);
	my $M = $self->quote_identifier("M");
	my $Q_ids = $self->quote_identifier("ids");

	my $sql = "SELECT $M.$Q_ids FROM $Q_table $M WHERE $condition";

	my $r = {};
	my $sth = $self->prepare( $sql );
	$self->execute( $sth, $sql );
	while( my @info = $sth->fetchrow_array ) {
		my @list = split(":",$info[0]);
		foreach( @list ) { next if $_ eq ""; $r->{$_}=1; }
	}
	$sth->finish;
	my $results = [ keys %{$r} ];
	return( $results );
}



######################################################################
=pod

=item $ids = $db->search( $keyfield, $tables, $conditions, [$main_table_alias] )

Return a reference to an array of ids - the results of the search
specified by $conditions accross the tables specified in the $tables
hash where keys are tables aliases and values are table names. 

If no table alias is passed then M is assumed. 

=cut
######################################################################

sub search
{
	my( $self, $keyfield, $tables, $conditions, $main_table_alias ) = @_;

	EPrints::abort "No SQL tables passed to search()" if( scalar keys %{$tables} == 0 );

	$main_table_alias = "M" unless defined $main_table_alias;

	my $sql = "SELECT DISTINCT ".$self->quote_identifier($main_table_alias, $keyfield->get_sql_name())." FROM ";
	my $first = 1;
	foreach( keys %{$tables} )
	{
		EPrints::abort "Empty string passed to search() as an SQL table" if( $tables->{$_} eq "" );
		$sql.= ", " unless($first);
		$first = 0;
		$sql.= $self->quote_identifier($tables->{$_})." ".$self->quote_identifier($_);
	}
	if( defined $conditions )
	{
		$sql .= " WHERE $conditions";
	}

	my $results = [];
	my $sth = $self->prepare( $sql );
	$self->execute( $sth, $sql );
	while( my @info = $sth->fetchrow_array ) {
		push @{$results}, $info[0];
	}
	$sth->finish;
	return( $results );
}




######################################################################
=pod

=item $db->drop_cache( $id )

Remove the cached search with the given id.

=cut
######################################################################

sub drop_cache
{
	my ( $self , $id ) = @_;

	if( defined( my $cache = $self->get_cachemap( $id ) ) )
	{
		$cache->remove;
	}
}


######################################################################
=pod

=item $n = $db->count_table( $tablename )

Return the number of rows in the specified SQL table.

=cut
######################################################################

sub count_table
{
	my ( $self , $tablename ) = @_;

	my $sql = "SELECT COUNT(*) FROM ".$self->quote_identifier($tablename);

	my $sth = $self->prepare( $sql );
	$self->execute( $sth, $sql );
	my ( $count ) = $sth->fetchrow_array;
	$sth->finish;

	return $count;
}

######################################################################
=pod

=item $foo = $db->from_cache( $dataset, $cacheid, [$offset], [$count], [$justids] )

Return a reference to an array containing all the items from the
given dataset that have id's in the specified cache. The cache may be 
specified either by id or serialised search expression. 

$offset is an offset from the start of the cache and $count is the number
of records to return.

If $justids is true then it returns just an ref to an array of the record
ids, not the objects.

=cut
######################################################################

sub from_cache
{
	my( $self , $dataset , $cacheid , $offset , $count , $justids) = @_;

	# Force offset and count to be ints
	$offset+=0;
	$count+=0;

	my @results;
	if( $justids )
	{
		my $keyfield = $dataset->get_key_field();

		my $Q_cache_table = $self->quote_identifier($self->cache_table($cacheid));
		my $C = $self->quote_identifier("C");
		my $Q_pos = $self->quote_identifier("pos");
		my $Q_keyname = $self->quote_identifier($keyfield->get_sql_name);

		my $sql = "SELECT $Q_keyname FROM $Q_cache_table $C ";
		$sql.= "WHERE $C.$Q_pos > ".$offset." ";
		if( $count > 0 )
		{
			$sql.="AND $C.$Q_pos <= ".($offset+$count)." ";
		}
		$sql .= "ORDER BY $C.$Q_pos";
		my $sth = $self->prepare( $sql );
		$self->execute( $sth, $sql );
		while( my @values = $sth->fetchrow_array ) 
		{
			push @results, $values[0];
		}
		$sth->finish;
	}
	else
	{
		@results = $self->_get( $dataset, 3, $self->cache_table($cacheid), $offset , $count );
	}

	if( defined( my $cache = $self->get_cachemap( $cacheid ) ) )
	{
		$cache->set_value( "lastused", time() );
		$cache->commit();
	}

	$self->drop_old_caches();

	return \@results;
}


######################################################################
=pod

=item $db->drop_old_caches

Drop all the expired caches.

=cut
######################################################################

sub drop_old_caches
{
	my( $self ) = @_;

	my $a = $self->{session}->get_repository;
	my $ds = $a->get_dataset( "cachemap" );

	my $Q_table = $self->quote_identifier($ds->get_sql_table_name);
	my $Q_cachemapid = $self->quote_identifier("cachemapid");
	my $Q_lastused = $self->quote_identifier("lastused");
	my $Q_created = $self->quote_identifier("created");
	my $Q_oneshot = $self->quote_identifier("oneshot");

	my $sql = "SELECT $Q_cachemapid FROM $Q_table WHERE";
	$sql.= " ($Q_lastused < ".(time() - ($a->get_conf("cache_timeout") + 5) * 60)." AND $Q_oneshot = 'FALSE')";
	$sql.= " OR $Q_created < ".(time() - $a->get_conf("cache_maxlife") * 3600);
	my $sth = $self->prepare( $sql );
	$self->execute( $sth , $sql );
	my $id;
	while( $id  = $sth->fetchrow_array() )
	{
		$self->drop_cache( $id );
	}
	$sth->finish;
}



######################################################################
=pod

=item $obj = $db->get_single( $dataset, $id )

Return a single item from the given dataset. The one with the specified
id.

=cut
######################################################################

sub get_single
{
	my ( $self , $dataset , $value ) = @_;
	return ($self->_get( $dataset, 0 , $value ))[0];
}


######################################################################
=pod

=item $items = $db->get_all( $dataset )

Returns a reference to an array with all the items from the given dataset.

=cut
######################################################################

sub get_all
{
	my ( $self , $dataset ) = @_;
	return $self->_get( $dataset, 2 );
}

######################################################################
# 
# $foo = $db->_get ( $dataset, $mode, $param, $offset, $ntoreturn )
#
# Scary generic function to get records from the database and put
# them together.
#
######################################################################

sub _get 
{
	my ( $self , $dataset , $mode , $param, $offset, $ntoreturn ) = @_;

	# debug code.
	if( !defined $dataset || ref($dataset) eq "") { EPrints::abort("no dataset passed to \$database->_get"); }

	# mode 0 = one or none entries from a given primary key
	# mode 1 = many entries from a buffer table
	# mode 2 = return the whole table (careful now)
	# mode 3 = some entries from a cache table

	my @fields = $dataset->get_fields( 1 );

	my $field = undef;
	my $keyfield = $fields[0];
	my $Q_keyname = $self->quote_identifier($keyfield->get_sql_name());

	my $cols = "";
	my @aux = ();
	my $first = 1;

	my $Q_table = $self->quote_identifier($dataset->get_sql_table_name());
	my $M = $self->quote_identifier("M");
	my $C = $self->quote_identifier("C");
	my $Q_pos = $self->quote_identifier("pos");

	foreach $field ( @fields ) 
	{
		next if( $field->is_virtual );

		if( $field->is_type( "secret" ) )
		{
			# We don't return the values of secret fields - 
			# much more secure that way. The password field is
			# accessed direct via SQL.
			next;
		}

		if( $field->get_property( "multiple" ) )
		{ 
			push @aux,$field;
			next;
		}

		if ($first)
		{
			$first = 0;
		}
		else
		{
			$cols .= ", ";
		}
		$cols .= join(", ", map {
			"$M.".$self->quote_identifier($_)
		} $field->get_sql_names);
	}

	my $sql;
	if ( $mode == 0 )
	{
		$sql = "SELECT $cols FROM $Q_table $M ".
		       "WHERE $M.$Q_keyname = ".$self->quote_value( $param );
	}
	elsif ( $mode == 1 )	
	{
		$sql = "SELECT $cols FROM ".$self->quote_identifier($param)." $C, $Q_table $M ".
		       "WHERE $M.$Q_keyname = $C.$Q_keyname";
	}
	elsif ( $mode == 2 )	
	{
		$sql = "SELECT $cols FROM $Q_table $M";
	}
	elsif ( $mode == 3 )	
	{
		$sql = "SELECT $cols, $C.$Q_pos FROM ".$self->quote_identifier($param)." $C, $Q_table $M ";
		$sql.= "WHERE $M.$Q_keyname = $C.$Q_keyname AND $C.$Q_pos>".$offset." ";
		if( $ntoreturn > 0 )
		{
			$sql.="AND $C.$Q_pos<=".($offset+$ntoreturn)." ";
		}
		$sql .= "ORDER BY $C.$Q_pos";
		#print STDERR "$sql\n";
	}
	my $sth = $self->prepare( $sql );
	$self->execute( $sth, $sql );
	my @data = ();
	my %lookup = ();
	my $count = 0;
	while( my @row = $sth->fetchrow_array ) 
	{
		my $record = {};
		$lookup{$row[0]} = $count;
		foreach $field ( @fields ) 
		{ 
			next if( $field->is_type( "secret" ) );
			next if( $field->is_virtual );

			if( $field->get_property( "multiple" ) )
			{
				#cjg Maybe should do nothing.
				$record->{$field->get_name()} = [];
				next;
			}

			my $value = $field->value_from_sql_row( $self->{session}, \@row );

			$record->{$field->get_name()} = $value;
		}
		$data[$count] = $record;
		$count++;
	}
	$sth->finish;

	foreach my $multifield ( @aux )
	{
		my $fn = $multifield->get_name();
		my $cols = "$M.$Q_keyname, ";
		if( $multifield->get_property( "multiple" ) )
		{
			$cols .= "$M.$Q_pos, "
		}
		$cols .= join(", ", map {
			"$M.".$self->quote_identifier($_)
		} $multifield->get_sql_names);
		my $Q_subtable = $self->quote_identifier($dataset->get_sql_sub_table_name( $multifield ));
		if( $mode == 0 )	
		{
			$sql = "SELECT $cols FROM $Q_subtable $M ";
			$sql.= "WHERE $M.$Q_keyname=".$self->quote_value( $param );
		}
		elsif( $mode == 1)
		{
			$sql = "SELECT $cols FROM $param $C, $Q_subtable $M ";
			$sql.= "WHERE $M.$Q_keyname=$C.$Q_keyname";
		}	
		elsif( $mode == 2)
		{
			$sql = "SELECT $cols FROM $Q_subtable $M ";
		}
		elsif ( $mode == 3 )	
		{
			$sql = "SELECT $cols, $C.$Q_pos FROM ".$self->quote_identifier($param)." $C, $Q_subtable $M ";
			$sql.= "WHERE $M.$Q_keyname = $C.$Q_keyname AND $C.$Q_pos>".$offset." ";
			if( $ntoreturn > 0 )
			{
				$sql.="AND $C.$Q_pos<=".($offset+$ntoreturn)." ";
			}
			$sql .= "ORDER BY $C.$Q_pos";
		}
		$sth = $self->prepare( $sql );
		$self->execute( $sth, $sql );
		while( my @values = $sth->fetchrow_array ) 
		{
			my $id = shift( @values );
			my( $pos, $lang );
			$pos = shift( @values ) if( $multifield->get_property( "multiple" ) );
			my $n = $lookup{ $id };
			my $value = $multifield->value_from_sql_row( $self->{session}, \@values );

			$data[$n]->{$fn}->[$pos] = $value;
		}
		$sth->finish;
	}	

	foreach( @data )
	{
		$_ = $dataset->make_object( $self->{session} ,  $_);
		$_->clear_changed();
	}

	return @data;
}


######################################################################
=pod

=item $foo = $db->get_values( $field, $dataset )

Return a reference to an array of all the distinct values of the 
EPrints::MetaField specified.

=cut
######################################################################

sub get_values
{
	my( $self, $field, $dataset ) = @_;

	# what if a subobjects field is called?
	if( $field->is_virtual )
	{
		$self->{session}->get_repository->log( 
"Attempt to call get_values on a virtual field." );
		return [];
	}

	my $M = $self->quote_identifier("M");
	my $L = $self->quote_identifier("L");
	my $Q_eprint_status = $self->quote_identifier( "eprint_status" );
	my $Q_eprintid = $self->quote_identifier( "eprintid" );

	my $cols = join(", ", map {
		"$M.".$self->quote_identifier($_)
	} $field->get_sql_names);
	my $sql = "SELECT DISTINCT $cols FROM ";
	my $limit;
	$limit = "archive" if( $dataset->id eq "archive" );
	$limit = "inbox" if( $dataset->id eq "inbox" );
	$limit = "deletion" if( $dataset->id eq "deletion" );
	$limit = "buffer" if( $dataset->id eq "buffer" );
	if( $field->get_property( "multiple" ) )
	{
		$sql.= $self->quote_identifier($dataset->get_sql_sub_table_name( $field ))." $M";
		if( $limit )
		{
			$sql.=", ".$self->quote_identifier($dataset->get_sql_table_name())." $L";
			$sql.=" WHERE $L.$Q_eprintid = $M.$Q_eprintid";
			$sql.=" AND $L.$Q_eprint_status = '$limit'";
		}
	} 
	else 
	{
		$sql.= $self->quote_identifier($dataset->get_sql_table_name())." $M";
		if( $limit )
		{
			$sql.=" WHERE $M.$Q_eprint_status = '$limit'";
		}
	}
	my $sth = $self->prepare( $sql );
	$self->execute( $sth, $sql );
	my @values = ();
	my @row = ();
	while( @row = $sth->fetchrow_array ) 
	{
		push @values, $field->value_from_sql_row( $self->{session}, \@row );
	}
	$sth->finish;
	return \@values;
}

######################################################################
=pod

=item $values = $db->sort_values( $field, $values [, $langid ] )

ALPHA!!! Liable to API change!!!

Sorts and returns the list of $values using the database.

$field is used to get the order value for each value. $langid (or $session->get_langid if unset) is used to determine the database collation to use when sorting the resulting order values.

=cut
######################################################################

sub sort_values
{
	my( $self, $field, $values, $langid ) = @_;

	my $session = $self->{session};

	$langid ||= $session->get_langid;

	# we'll use a cachemap but inverted (order by the key and use the pos)
	my $cachemap = EPrints::DataObj::Cachemap->create_from_data( $session, {
		lastused => time(),
		oneshot => "TRUE",
	});
	my $table  = $cachemap->get_sql_table_name;

	# collation-aware field to use to order by
	my $ofield = $field->create_ordervalues_field(
		$session,
		$langid
	);

	# create a table to sort the values in
	$self->_create_table( $table, [ "pos" ], [
		$self->get_column_type( "pos", SQL_INTEGER, SQL_NOT_NULL ),
		$ofield->get_sql_type( $session, 1 ),
	]);

	# insert all the order values with their index in $values
	my @pairs;
	my $i = 0;
	foreach(@$values)
	{
		push @pairs, [
			$i++,
			$field->ordervalue_single( $_, $session, $langid )
		];
	}
	$self->insert( $table, [ "pos", $ofield->get_sql_names ], @pairs );

	# retrieve the order the values should be in
	my $Q_table = $self->quote_identifier( $table );
	my $Q_index = $self->quote_identifier( "pos" );
	my $Q_ovalue = $self->quote_identifier( $ofield->get_sql_names );
	my $sth = $self->prepare( "SELECT $Q_index FROM $Q_table ORDER BY $Q_ovalue ASC" );
	$sth->execute;
	my @values;
	my $row;
	while( $row = $sth->fetch ) 
	{
		push @values, $values->[$row->[0]];
	}
	$sth->finish;

	# clean up
	$cachemap->remove();

	return \@values;
}

######################################################################
=pod

=item $ids = $db->get_ids_by_field_values( $field, $dataset [ %opts ] )

Return a reference to a hash table where the keys are field value ids and the value is a reference to an array of ids.

=cut
######################################################################

sub get_ids_by_field_values
{
	my( $self, $field, $dataset, %opts ) = @_;

	# what if a subobjects field is called?
	if( $field->is_virtual )
	{
		$self->{session}->get_repository->log( 
"Attempt to call get_ids_by_field_values on a virtual field." );
		return [];
	}

	my $session = $self->{session};

	my $keyfield = $dataset->get_key_field();

	my %tables = ();
	my $srctable;
	if( $field->get_property( "multiple" ) )
	{
		$srctable = $dataset->get_sql_sub_table_name( $field );
	}
	else
	{
		$srctable = $dataset->get_sql_table_name();
	}
	$tables{$srctable} = 1;

	my @cols = (
		$keyfield->get_sql_names(),
		$field->get_sql_names(),
	);

	my @where = ();

	if( $dataset->confid eq "eprint" && $dataset->id ne $dataset->confid )
	{
		my $table = $dataset->get_sql_table_name();
		$tables{$table} = 1;
		push @where,
			$self->quote_identifier($table, "eprint_status").
			" = ".
			$self->quote_value($dataset->id);
	}

	if( defined $opts{filters} )
	{
		foreach my $filter (@{$opts{filters}})
		{
			my @ors = ();
			foreach my $ffield ( @{$filter->{fields}} )
			{	
				my $table;
				if( $ffield->get_property( "multiple" ) )
				{
					$table = $dataset->get_sql_sub_table_name( $ffield );
				}
				else
				{
					$table = $dataset->get_sql_table_name();
				}
				$tables{$table} = 1;
				# note filters don't handle date, time or name fields yet.
				push @ors,
					$self->quote_identifier($table,$ffield->get_sql_name()).
					" = ".
					$self->quote_value( $filter->{value} );
			}
			push @where, "(".join( ") OR (", @ors ).")";
		}
	}

	foreach my $table (keys %tables)
	{
		next if $srctable eq $table;
		push @where,
			$self->quote_identifier($srctable,"eprintid").
			" = ".
			$self->quote_identifier($table,"eprintid");
	}

	my $sql = "SELECT DISTINCT ";
	$sql .= join(",",map { $self->quote_identifier($srctable,$_) } @cols);
	$sql .= " FROM ".join( ",", map { $self->quote_identifier($_) } keys %tables );
	$sql .= " WHERE ".join( " AND ", @where ) if @where;

	my $sth = $self->prepare( $sql );
	$self->execute( $sth, $sql );
	my $ids = {};
	while(my( $eprintid, @row ) = $sth->fetchrow_array ) 
	{
		my $value = $field->value_from_sql_row( $session, \@row );
		my $id = $field->get_id_from_value( $session, $value );
		push @{$ids->{$id}}, $eprintid;
	}
	$sth->finish;

	return $ids;
}

######################################################################
=pod

=item $success = $db->do( $sql )

Execute the given SQL.

=cut
######################################################################

sub do 
{
	my( $self , $sql ) = @_;

	if( $self->{session}->get_repository->can_call( 'sql_adjust' ) )
	{
		$sql = $self->{session}->get_repository->call( 'sql_adjust', $sql );
	}
	
	if( $self->{debug} )
	{
		$self->{session}->get_repository->log( "Database execute debug: $sql" );
	}
	my $result = $self->{dbh}->do( $sql );

	if( !$result )
	{
		$self->{session}->get_repository->log( "SQL ERROR (do): $sql" );
		$self->{session}->get_repository->log( "SQL ERROR (do): ".$self->{dbh}->errstr.' (#'.$self->{dbh}->err.')' );

		return undef unless( $self->{dbh}->err == 2006 );

		my $ccount = 0;
		while( $ccount < 10 )
		{
			++$ccount;
			sleep 3;
			$self->{session}->get_repository->log( "Attempting DB reconnect: $ccount" );
			$self->connect;
			if( defined $self->{dbh} )
			{
				$result = $self->{dbh}->do( $sql );
				return 1 if( defined $result );
				$self->{session}->get_repository->log( "SQL ERROR (do): ".$self->{dbh}->errstr );
			}
		}
		$self->{session}->get_repository->log( "Giving up after 10 tries" );
		return undef;
	}

	if( defined $result )
	{
		return 1;
	}

	return undef;
}


######################################################################
=pod

=item $sth = $db->prepare( $sql )

Prepare the given $sql and return a handle on it.

=cut
######################################################################

sub prepare 
{
	my ( $self , $sql ) = @_;

	if( $self->{session}->get_repository->can_call( 'sql_adjust' ) )
	{
		$sql = $self->{session}->get_repository->call( 'sql_adjust', $sql );
	}
	
#	if( $self->{debug} )
#	{
#		$self->{session}->get_repository->log( "Database prepare debug: $sql" );
#	}

	my $result = $self->{dbh}->prepare( $sql );
	my $ccount = 0;
	if( !$result )
	{
		$self->{session}->get_repository->log( "SQL ERROR (prepare): $sql" );
		$self->{session}->get_repository->log( "SQL ERROR (prepare): ".$self->{dbh}->errstr.' (#'.$self->{dbh}->err.')' );

		# MySQL disconnect?
		if( $self->{dbh}->err == 2006 )
		{
			EPrints::abort( $self->{dbh}->{errstr} );
		}

		my $ccount = 0;
		while( $ccount < 10 )
		{
			++$ccount;
			sleep 3;
			$self->{session}->get_repository->log( "Attempting DB reconnect: $ccount" );
			$self->connect;
			if( defined $self->{dbh} )
			{
				$result = $self->{dbh}->prepare( $sql );
				return $result if( defined $result );
				$self->{session}->get_repository->log( "SQL ERROR (prepare): ".$self->{dbh}->errstr );
			}
		}
		$self->{session}->get_repository->log( "Giving up after 10 tries" );

		EPrints::abort( $self->{dbh}->{errstr} );
	}

	return $result;
}


######################################################################
=pod

=item $success = $db->execute( $sth, $sql )

Execute the SQL prepared earlier. $sql is only passed in for debugging
purposes.

=cut
######################################################################

sub execute 
{
	my( $self , $sth , $sql ) = @_;

	if( $self->{debug} )
	{
		$self->{session}->get_repository->log( "Database execute debug: $sql" );
	}

	my $result = $sth->execute;
	while( !$result )
	{
		$self->{session}->get_repository->log( "SQL ERROR (execute): $sql" );
		$self->{session}->get_repository->log( "SQL ERROR (execute): ".$self->{dbh}->errstr );
		return undef;
	}

	return $result;
}

######################################################################
=pod

=item $db->has_dataset( $dataset )

Returns true if $dataset exists in the database or has no database tables.

This does not check that all fields are configured - see has_field().

=cut
######################################################################

sub has_dataset
{
	my( $self, $dataset ) = @_;

	my $rc = 1;

	my $table = $dataset->get_sql_table_name;

	$rc &&= $self->has_table( $table );

	foreach my $langid ( @{$self->{session}->get_repository->get_conf( "languages" )} )
	{
		my $order_table = $dataset->get_ordervalues_table_name( $langid );

		$rc &&= $self->has_table( $order_table );
	}

	return $rc;
}

######################################################################
=pod

=item $db->has_field( $dataset, $field )

Returns true if $field is in the database for $dataset.

=cut
######################################################################

sub has_field
{
	my( $self, $dataset, $field ) = @_;

	my $rc = 1;

	# If this field is virtual and has sub-fields, check them
	if( $field->isa( "EPrints::MetaField::Compound" ) )
	{
		my $sub_fields = $field->get_property( "fields_cache" );
		foreach my $sub_field (@$sub_fields)
		{
			$rc &&= $self->has_field( $dataset, $sub_field );
		}
	}
	else # Check the field itself
	{
		$rc &&= $self->_has_field( $dataset, $field );
	}

	# Check the order values (used to order search results)
	$rc &&= $self->_has_field_ordervalues( $dataset, $field );

	return $rc;
}

sub _has_field
{
	my( $self, $dataset, $field ) = @_;

	my $rc = 1;

	return $rc if $field->is_virtual;

	if( $field->get_property( "multiple" ) )
	{
		my $table = $dataset->get_sql_sub_table_name( $field );

		$rc &&= $self->has_table( $table );
	}
	else
	{
		my $table = $dataset->get_sql_table_name;
		my $first_column = ($field->get_sql_names)[0];

		$rc &&= $self->has_column( $table, $first_column );
	}

	return $rc;
}

######################################################################
=pod

=item $db->add_field( $dataset, $field )

Add $field to $dataset's tables.

=cut
######################################################################

sub add_field
{
	my( $self, $dataset, $field ) = @_;

	my $rc = 1;

	# If this field is virtual and has sub-fields, add them
	if( $field->isa( "EPrints::MetaField::Compound" ) )
	{
		my $sub_fields = $field->get_property( "fields_cache" );
		foreach my $sub_field (@$sub_fields)
		{
			$rc &&= $self->add_field( $dataset, $sub_field );
		}
	}
	else # Add the field itself to the metadata table
	{
		$rc &&= $self->_add_field( $dataset, $field );
	}

	# Add the field to order values (used to order search results)
	$rc &&= $self->_add_field_ordervalues( $dataset, $field );

	return $rc;
}

# Split a sql type definition into its constituant columns
sub _split_sql_type
{
	my( $sql ) = @_;
	my @types;
	my $type = "";
	while(length($sql))
	{
	for($sql)
	{
		if( s/^\s+// )
		{
		}
		elsif( s/^[^,\(]+// )
		{
			$type .= $&;
		}
		elsif( s/^\(// )
		{
			$type .= $&;
			s/^[^\)]+\)// and $type .= $&;
		}
		elsif( s/^,\s*// )
		{
			push @types, $type;
			$type = "";
		}
	}
	}
	push @types, $type if $type ne "";
	return @types;
}

sub _has_field_ordervalues
{
	my( $self, $dataset, $field ) = @_;

	my $rc = 1;

	foreach my $langid ( @{$self->{ session }->get_repository->get_conf( "languages" )} )
	{
		$rc &&= $self->_has_field_ordervalues_lang( $dataset, $field, $langid );
	}

	return $rc;
}

sub _has_field_ordervalues_lang
{
	my( $self, $dataset, $field, $langid ) = @_;

	my $order_table = $dataset->get_ordervalues_table_name( $langid );

	return $self->has_column( $order_table, $field->get_sql_name() );
}

# Add the field to the ordervalues tables
sub _add_field_ordervalues
{
	my( $self, $dataset, $field ) = @_;

	my $rc = 1;

	foreach my $langid ( @{$self->{ session }->get_repository->get_conf( "languages" )} )
	{
		next if $self->_has_field_ordervalues_lang( $dataset, $field, $langid );
		$rc &&= $self->_add_field_ordervalues_lang( $dataset, $field, $langid );
	}

	return $rc;
}

# Add the field to the ordervalues table for $langid
sub _add_field_ordervalues_lang
{
	my( $self, $dataset, $field, $langid ) = @_;

	my $order_table = $dataset->get_ordervalues_table_name( $langid );

	my $sql_field = EPrints::MetaField->new(
		repository => $self->{ session }->get_repository,
		name => $field->get_sql_name(),
		type => "longtext" );

	my $col = $sql_field->get_sql_type( $self->{session}, 0 ); # only first field can not be null

	return $self->do( "ALTER TABLE ".$self->quote_identifier($order_table)." ADD $col" );
}

# Add the field to the main tables
sub _add_field
{
	my( $self, $dataset, $field ) = @_;

	my $rc = 1;

	return $rc if $field->is_virtual; # Virtual fields are still added to ordervalues???

	if( $field->get_property( "multiple" ) )
	{
		return $self->_add_multiple_field( $dataset, $field );
	}

	my $table = $dataset->get_sql_table_name;

	return $rc if $self->has_column( $table, $field->get_sql_name() );

	my $cols = $field->get_sql_type( $self->{session}, 0 );
	for(_split_sql_type($cols))
	{
		$rc &&= $self->do( "ALTER TABLE ".$self->quote_identifier($table)." ADD $_" );
	}
	if( my @columns = $field->get_sql_index )
	{
		$rc &&= $self->create_index( $table, @columns );
	}

	return $rc;
}

# Add a multiple field to the main tables
sub _add_multiple_field
{
	my( $self, $dataset, $field ) = @_;

	my $table = $dataset->get_sql_sub_table_name( $field );
	
	return 1 if $self->has_table( $table );

	my $key_field = $dataset->get_key_field();

	# $database->create_table spots multiples and attempts to create auxillary tables, which we don't want to do
	my $aux_field = $field->clone;
	$aux_field->set_property( "multiple", 0 );

	my $pos_field = EPrints::MetaField->new(
		repository => $self->{ session }->get_repository,
		name => "pos",
		type => "int" );

	return $self->create_table(
		$table,
		$dataset,
		0,
		( $key_field, $pos_field, $aux_field ) );
}

######################################################################
=pod

=item $db->remove_field( $dataset, $field )

Remove $field from $dataset's tables.

=cut
######################################################################

sub remove_field
{
	my( $self, $dataset, $field ) = @_;

	# If this field is virtual and has sub-fields, remove them
	if( $field->is_virtual )
	{
		my $sub_fields = $field->get_property( "fields_cache" );
		foreach my $sub_field (@$sub_fields)
		{
			$self->remove_field( $dataset, $sub_field );
		}
	}
	else # Remove the field itself from the metadata table
	{
		$self->_remove_field( $dataset, $field );
	}

	# Remove the field from order values (used to order search results)
	$self->_remove_field_ordervalues( $dataset, $field );
}

# Remove the field from the ordervalues tables
sub _remove_field_ordervalues
{
	my( $self, $dataset, $field ) = @_;

	foreach my $langid ( @{$self->{ session }->get_repository->get_conf( "languages" )} )
	{
		$self->_remove_field_ordervalues_lang( $dataset, $field, $langid );
	}
}

# Remove the field from the ordervalues table for $langid
sub _remove_field_ordervalues_lang
{
	my( $self, $dataset, $field, $langid ) = @_;

	my $order_table = $dataset->get_ordervalues_table_name( $langid );

	my $column_sql = "DROP COLUMN ".$self->quote_identifier($field->get_sql_name);

	return $self->do( "ALTER TABLE ".$self->quote_identifier($order_table)." $column_sql" );
}

# Remove the field from the main tables
sub _remove_field
{
	my( $self, $dataset, $field ) = @_;

	my $rc = 1;

	return if $field->is_virtual; # Virtual fields are still removed from ordervalues???

	if( $field->get_property( "multiple" ) )
	{
		return $self->_remove_multiple_field( $dataset, $field );
	}

	my $Q_table = $self->quote_identifier($dataset->get_sql_table_name);

	for($field->get_sql_names)
	{
		$rc &&= $self->do( "ALTER TABLE $Q_table DROP COLUMN ".$self->quote_identifier($_) );
	}

	return $rc;
}

# Remove a multiple field from the main tables
sub _remove_multiple_field
{
	my( $self, $dataset, $field ) = @_;

	my $table = $dataset->get_sql_sub_table_name( $field );

	$self->do( "DROP TABLE ".$self->quote_identifier($table) );
}

######################################################################
=pod

=item $boolean = $db->exists( $dataset, $id )

Return true if a record with the given primary key exists in the
dataset, otherwise false.

=cut
######################################################################

sub exists
{
	my( $self, $dataset, $id ) = @_;

	if( !defined $id )
	{
		return undef;
	}
	
	my $keyfield = $dataset->get_key_field();

	my $Q_table = $self->quote_identifier($dataset->get_sql_table_name);
	my $Q_column = $self->quote_identifier($keyfield->get_sql_name);
	my $sql = "SELECT 1 FROM $Q_table WHERE $Q_column=".$self->quote_value( $id );

	my $sth = $self->prepare( $sql );
	$self->execute( $sth , $sql );
	my( $result ) = $sth->fetchrow_array;
	$sth->finish;

	return $result ? 1 : 0;
}



######################################################################
=pod

=item $db->set_debug( $boolean )

Set the SQL debug mode to true or false.

=cut
######################################################################

sub set_debug
{
	my( $self, $debug ) = @_;

	$self->{debug} = $debug;
}

######################################################################
=pod

=item $db->create_version_table

Make the version table (and set the only value to be the current
version of eprints).

=cut
######################################################################

sub create_version_table
{
	my( $self ) = @_;

	my $table = "version";
	my $column = "version";

	$self->_create_table($table, [], [
		$self->get_column_type( $column, SQL_VARCHAR, SQL_NULL, 255 ),
	]);

	$self->insert( $table, [$column], [undef] );
}

######################################################################
=pod

=item $db->set_version( $versionid );

Set the version id table in the SQL database to the given value
(used by the upgrade script).

=cut
######################################################################

sub set_version
{
	my( $self, $versionid ) = @_;

	my $sql;

	my $Q_version = $self->quote_identifier( "version" );

	$sql = "UPDATE $Q_version SET $Q_version = ".$self->quote_value( $versionid );
	$self->do( $sql );

	if( $self->{session}->get_noise >= 1 )
	{
		print "Set DB compatibility flag to '$versionid'.\n";
	}
}

######################################################################
=pod

=item $boolean = $db->has_table( $tablename )

Return true if a table of the given name exists in the database.

=cut
######################################################################

sub has_table
{
	my( $self, $tablename ) = @_;

	my $sth = $self->{dbh}->table_info( '%', '%', $tablename, 'TABLE' );
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

	my $sth = $self->{dbh}->column_info( '%', '%', $table, $column );
	while(!$rc && (my $row = $sth->fetch))
	{
		my $column_name = $row->[$sth->{NAME_lc_hash}{column_name}];
		$rc = 1 if $column_name eq $column;
	}
	$sth->finish;

	return $rc;
}

######################################################################
=pod

=item $db->drop_table( $tablename )

Delete the named table. Use with caution!

=cut
######################################################################
	
sub drop_table
{
	my( $self, $tablename ) = @_;

	return 1 unless $self->has_table( $tablename );

	my $sql = "DROP TABLE ".$self->quote_identifier($tablename);
	$self->do( $sql );
}

######################################################################
=pod

=item $db->clear_table( $tablename )

Clears all records from the given table, use with caution!

=cut
######################################################################
	
sub clear_table
{
	my( $self, $tablename ) = @_;

	my $sql = "DELETE FROM ".$self->quote_identifier($tablename);
	$self->do( $sql );
}

######################################################################
=pod

=item $db->rename_table( $tablename, $newtablename )

Renames the table from the old name to the new one.

=cut
######################################################################

sub rename_table
{
	my( $self, $table_from, $table_to ) = @_;

	my $sql = "RENAME TABLE $table_from TO $table_to";
	$self->do( $sql );
}

######################################################################
=pod

=item $db->swap_table( $table_a, $table_b )

Swap table a and table b. 

=cut
######################################################################

sub swap_tables
{
	my( $self, $table_a, $table_b ) = @_;

	my $tmp = $table_a.'_swap';
	my $sql = "RENAME TABLE $table_a TO $tmp, $table_b TO $table_a, $tmp TO $table_b";
	$self->do( $sql );
}

######################################################################
=pod

=item @tables = $db->get_tables

Return a list of all the tables in the database.

=cut
######################################################################

sub get_tables
{
	my( $self ) = @_;

	my @tables;

	my $sth = $self->{dbh}->table_info( '%', '%', '%', 'TABLE' );

	while(my $row = $sth->fetch)
	{
		push @tables, $row->[$sth->{NAME_lc_hash}{table_name}];
	}
	$sth->finish;

	return @tables;
}


######################################################################
=pod

=item $version = $db->get_version

Return the version of eprints which the database is compatable with
or undef if unknown (before v2.1).

=cut
######################################################################

sub get_version
{
	my( $self ) = @_;

	return undef unless $self->has_table( "version" );

	my $Q_version = $self->quote_identifier( "version" );

	my $sql = "SELECT $Q_version FROM $Q_version";
	my( $version ) = $self->{dbh}->selectrow_array( $sql );

	return $version;
}

######################################################################
=pod

=item $boolean = $db->is_latest_version

Return true if the SQL tables are in the correct configuration for
this edition of eprints. Otherwise false.

=cut
######################################################################

sub is_latest_version
{
	my( $self ) = @_;

	my $version = $self->get_version;
	return 0 unless( defined $version );

	return $version eq $EPrints::Database::DBVersion;
}

######################################################################
=pod

=item $db->valid_login( $username, $password )

Returns whether the clear-text $password matches the stored crypted password
for $username.

=cut
######################################################################

sub valid_login
{
	my( $self, $username, $password ) = @_;

	my $Q_password = $self->quote_identifier( "password" );
	my $Q_table = $self->quote_identifier( "user" );
	my $Q_username = $self->quote_identifier( "username" );

	my $sql = "SELECT $Q_password FROM $Q_table WHERE $Q_username=".$self->quote_value($username);

	my $sth = $self->prepare( $sql );
	$self->execute( $sth , $sql );
	my( $real_password ) = $sth->fetchrow_array;
	$sth->finish;

	return 0 if( !defined $real_password );

	my $salt = substr( $real_password, 0, 2 );

	return $real_password eq crypt( $password , $salt );
}


######################################################################
=pod

=item $db->index_queue( $datasetid, $objectid, $fieldname [, $fieldname ] );

Queues the field of the specified object to be reindexed.

=cut
######################################################################

sub index_queue
{
	my( $self, $datasetid, $objectid, @fieldnames ) = @_; 

	my $rc = 1;

	return $rc unless @fieldnames;

	my $table = "index_queue";

	# SYSDATE is the date/time at the point of insertion, but is supported
	# by most databases unlike NOW(), which is only in MySQL
	my $sql = "INSERT INTO ".$self->quote_identifier($table)." (".
		join(',',map { $self->quote_identifier($_) } qw( field added )).
		") VALUES (?, SYSDATE)";
	my $sth = $self->prepare($sql);
	for(@fieldnames)
	{
		$rc &&= $sth->execute( "$datasetid.$objectid.$_" );
	}

	return $rc;
}

######################################################################
=pod

=item ($datasetid, $objectid, $field) = $db->index_dequeue();

Pops an item off the queue. Returns empty list if nothing left.

=cut
######################################################################

sub index_dequeue
{
	my( $self ) = @_;

	my $Q_field = $self->quote_identifier( "field" );
	my $Q_table = $self->quote_identifier( "index_queue" );
	my $Q_added = $self->quote_identifier( "added" );

	my $sql = "SELECT $Q_field FROM $Q_table ORDER BY $Q_added ASC LIMIT 1";
	my $sth = $self->prepare( $sql );
	$self->execute( $sth, $sql );
	my( $field ) = $sth->fetchrow_array;
	$sth->finish;

	return () unless defined $field;

	$sql = "DELETE FROM $Q_table WHERE $Q_field=".$self->quote_value($field);
	$self->do( $sql );

	return split(/\./, $field);
}

######################################################################
=pod

=item $version = $db->get_server_version

Return the database server version.

=cut
######################################################################

sub get_server_version;

######################################################################
=pod

=item $driver = $db->get_driver_name

Return the database driver name.

=cut
######################################################################

sub get_driver_name
{
	my( $self ) = @_;

	my $dbd = $self->{dbh}->{Driver}->{Name};
	my $dbd_version = eval "return \$DBD::${dbd}::VERSION";

	return ref($self)." [DBI $DBI::VERSION, DBD::$dbd $dbd_version]";
}

1; # For use/require success

######################################################################
=pod

=back

=cut

