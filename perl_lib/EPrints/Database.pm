######################################################################
#
# EPrints::Database
#
######################################################################
#
#
######################################################################


=pod

=for Pod2Wiki

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

package EPrints::Database;

use DBI ();
use Digest::MD5;

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
	SQL_BIGINT => DBI::SQL_BIGINT,
	SQL_REAL => DBI::SQL_REAL,
	SQL_DOUBLE => DBI::SQL_DOUBLE,
	SQL_DATE => DBI::SQL_DATE,
	SQL_TIME => DBI::SQL_TIME,
	SQL_CLOB => DBI::SQL_CLOB,
	SQL_DECIMAL => DBI::SQL_DECIMAL,
};

%EXPORT_TAGS = (
	sql_types => [qw(
		SQL_NULL
		SQL_NOT_NULL
		SQL_VARCHAR
		SQL_LONGVARCHAR
		SQL_CLOB
		SQL_VARBINARY
		SQL_LONGVARBINARY
		SQL_TINYINT
		SQL_SMALLINT
		SQL_INTEGER
		SQL_BIGINT
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
$EPrints::Database::DBVersion = "3.3.4";


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
        $dsn.= ";mysql_enable_utf8=1";
        return $dsn;
}

sub _new
{
	my( $class, $session ) = @_;

	my $driver = $session->config( "dbdriver" );
	$driver ||= "mysql";

	$class = "${class}::$driver";
	eval "use $class; 1";
	die $@ if $@;

	my $self = bless { session => $session }, $class;
	Scalar::Util::weaken($self->{session})
		if defined &Scalar::Util::weaken;

	$self->{debug} = $DEBUG_SQL;
	if( $session->{noise} == 3 )
	{
		$self->{debug} = 1;
	}

	return $self;
}

=item $db = $db->create( $username, $password )

Create and connect to a new database using super user account $username and $password.

=cut

sub create
{
	my( $self, $username, $password ) = @_;

	EPrints::abort( "Current database driver does not support database creation" );
}

######################################################################
=pod

=item $db = EPrints::Database->new( $session )

Create a connection to the database.

=cut
######################################################################

sub new
{
	my( $class, $session, %opts ) = @_;

	my $db_connect = exists($opts{db_connect}) ? $opts{db_connect} : 1;

	my $self = $class->_new( $session );

	if( $db_connect )
	{
		$self->connect;
		if( !defined $self->{dbh} ) { return( undef ); }
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

	my $repo = $self->{session};

	# Connect to the database
	$self->{dbh} = DBI->connect_cached( 
			build_connection_string( 
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

	foreach( $self->{session}->get_repository->get_sql_dataset_ids )
	{
		$success = $success && $self->create_dataset_tables( 
			$self->{session}->get_repository->get_dataset( $_ ) );
	}

	$success = $success && $self->create_counters();

	$self->create_version_table;	
	
	$self->set_version( $EPrints::Database::DBVersion );
	
	return( $success );
}

=item $db->drop_archive_tables()

Destroy all tables used by eprints in the database.

=cut

sub drop_archive_tables
{
	my( $self ) = @_;

	my $success = 1;

	foreach( $self->{session}->get_sql_dataset_ids )
	{
		$success |= $self->drop_dataset_tables( 
			$self->{session}->dataset( $_ ) );
	}

	$success |= $self->remove_counters();

	$self->drop_version_table;
	
	foreach my $table ($self->get_tables)
	{
		if( $table =~ /^cache\d+$/i )
		{
			$self->drop_table( $table );
		}
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

	my @main_fields;
	my @aux_fields;

	foreach my $field ($dataset->fields)
	{
		next if $field->is_virtual;
		if( $field->property( "multiple") )
		{
			push @aux_fields, $field;
		}
		else
		{
			push @main_fields, $field;
		}
	}

	my $main_table = $dataset->get_sql_table_name;

	# Create the main tables
	if( !$self->has_table( $main_table ) )
	{
		$rv &&= $self->create_table( $main_table, 1, @main_fields );
	}

	# Create the auxiliary tables
	foreach my $field (@aux_fields)
	{
		my $table = $dataset->get_sql_sub_table_name( $field );
		next if $self->has_table( $table );

		my $key_field = $dataset->key_field;

		my $pos = EPrints::MetaField->new( 
				repository => $self->{session},
				name => "pos", 
				type => "int",
				sql_index => 1,
			);

		my $aux_field = $field->clone;
		$aux_field->set_property( "multiple", 0 );

		$rv &&= $self->create_table( $table, 2, $key_field, $pos, $aux_field );
		$rv &&= $self->create_foreign_key( $main_table, $table, $key_field );
	}

	# Create the index tables
	if( $dataset->indexable )
	{
		$rv &&= $self->create_dataset_index_tables( $dataset );
	}

	# Create the ordervalues tables
	$rv &&= $self->create_dataset_ordervalues_tables( $dataset );

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

	my @tables;

	foreach my $field ($dataset->fields)
	{
		next if $field->is_virtual;
		next if !$field->property( "multiple" );
		push @tables, $dataset->get_sql_sub_table_name( $field );
	}

	foreach my $langid ( @{$self->{session}->config( "languages" )} )
	{
		push @tables, $dataset->get_ordervalues_table_name( $langid );
	}

	if( $dataset->indexable )
	{
		push @tables, 
			$dataset->get_sql_index_table_name,
			$dataset->get_sql_grep_table_name,
			$dataset->get_sql_rindex_table_name
		;
	}

	push @tables, $dataset->get_sql_table_name;

	if( $self->{session}->get_noise >= 1 )
	{
		print "Removing ".$dataset->id."\n";
		print "\t$_\n" for @tables;
	}

	$self->drop_table( @tables );

	return 1;
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

	$keyfield->set_property( allow_null => 0 );

	my $field_fieldword = EPrints::MetaField->new( 
		repository=> $self->{session}->get_repository,
		name => "fieldword", 
		type => "text",
		maxlength => 128,
		allow_null => 0);
	my $field_pos = EPrints::MetaField->new( 
		repository=> $self->{session}->get_repository,
		name => "pos", 
		type => "int",
		sql_index => 0,
		allow_null => 0);
	my $field_ids = EPrints::MetaField->new( 
		repository=> $self->{session}->get_repository,
		name => "ids", 
		type => "longtext",
		allow_null => 0);
	if( !$self->has_table( $dataset->get_sql_index_table_name ) )
	{
		$rv &= $self->create_table(
			$dataset->get_sql_index_table_name,
			2, # primary key over word/pos
			( $field_fieldword, $field_pos, $field_ids ) );
	}

	#######################

		
	my $field_fieldname = EPrints::MetaField->new( 
		repository=> $self->{session}->get_repository,
		name => "fieldname", 
		type => "text",
		maxlength => 64,
		allow_null => 0 );
	my $field_grepstring = EPrints::MetaField->new( 
		repository=> $self->{session}->get_repository,
		name => "grepstring", 
		type => "text",
		maxlength => 128,
		allow_null => 0 );

	if( !$self->has_table( $dataset->get_sql_grep_table_name ) )
	{
		$rv = $rv & $self->create_table(
			$dataset->get_sql_grep_table_name,
			3, # no primary key
			( $field_fieldname, $field_grepstring, $keyfield ) );
		$rv &= $self->create_foreign_key(
			$dataset->get_sql_table_name,
			$dataset->get_sql_grep_table_name,
			$keyfield );
	}


	return 0 unless $rv;
	###########################

	my $field_field = EPrints::MetaField->new( 
		repository=> $self->{session}->get_repository,
		name => "field", 
		type => "text",
		maxlength => 64,
		allow_null => 0 );
	my $field_word = EPrints::MetaField->new( 
		repository=> $self->{session}->get_repository,
		name => "word", 
		type => "text",
		maxlength => 128,
		allow_null => 0 );

	my $rindex_table = $dataset->get_sql_rindex_table_name;

	if( !$self->has_table( $rindex_table ) )
	{
		local $keyfield->{sql_index} = 0; # See KEY added below
		$rv = $rv & $self->create_table(
			$rindex_table,
			3, # primary key over all fields
			( $field_field, $field_word, $keyfield ) );
		$rv &= $self->create_foreign_key(
			$dataset->get_sql_table_name,
			$dataset->get_sql_rindex_table_name,
			$keyfield );
	}
	if( !defined($self->index_name( $rindex_table, $keyfield->get_sql_name, $field_field->get_sql_name )) )
	{
		# KEY(id,field) - used by deletion
		$rv = $rv & $self->create_index(
			$dataset->get_sql_rindex_table_name,
			$keyfield->get_sql_name, $field_field->get_sql_name
		);
	}

	return $rv;
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
				1, 
				@orderfields );
			$rv &&= $self->create_foreign_key(
				$dataset->get_sql_table_name,
				$order_table,
				$keyfield );
		}
	}

	return $rv;
}

=item $type_info = $db->type_info( DATA_TYPE )

See L<DBI/type_info>.

=cut

sub type_info
{
	my( $self, $data_type ) = @_;

	if( $data_type eq SQL_BIGINT )
	{
		return {
			TYPE_NAME => "bigint",
			CREATE_PARAMS => "",
			COLUMN_SIZE => 19,
		};
	}
	else
	{
		return $self->{dbh}->type_info( $data_type );
	}
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

Character data: SQL_VARCHAR(n), SQL_LONGVARCHAR, SQL_CLOB.

Binary data: SQL_VARBINARY(n), SQL_LONGVARBINARY.

Integer data: SQL_TINYINT, SQL_SMALLINT, SQL_INTEGER, SQL_BIGINT.

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

	my $type_info = $self->type_info( $data_type );
	my( $db_type, $params ) = @$type_info{
		qw( TYPE_NAME CREATE_PARAMS )
	};

	if( !defined $db_type )
	{
		no strict "refs";
		foreach my $type (@{$EPrints::Database::EXPORT_TAGS{sql_types}})
		{
			if( $data_type == &$type )
			{
				EPrints::abort( "DBI driver does not appear to support $type" );
			}
		}
		EPrints::abort( "Unknown SQL data type, must be one of: ".join(', ', @{$EPrints::Database::EXPORT_TAGS{sql_types}}) );
	}

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

	if(
		$data_type eq SQL_VARCHAR() or
		$data_type eq SQL_LONGVARCHAR() or
		$data_type eq SQL_CLOB()
	  )
	{
		my $langid = $opts{langid};
		if( !defined $langid )
		{
			$langid = "en";
		}

		my $charset = $self->get_default_charset( $langid );
		if( !defined $charset )
		{
			$charset = "UTF8";
		}

		$type .= " CHARACTER SET ".$charset;

		my $collate = $self->get_default_collation( $langid );
		if( defined( $collate ) )
		{
			$type .= " COLLATE ".$collate;
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

=item  $success = $db->create_table( $tablename, $setkey, @fields );

Creates a new table $tablename based on @fields.

The first $setkey number of fields are used for a primary key.

=cut
######################################################################

sub create_table
{
	my( $self, $tablename, $setkey, @fields ) = @_;
	
	my $rv = 1;

	# PRIMARY KEY
	my @primary_key;
	foreach my $i (0..$setkey-1)
	{
		my $field = $fields[$i] = $fields[$i]->clone;

		# PRIMARY KEY columns must be NOT NULL
		$field->set_property( allow_null => 0 );
		# don't need a key because the DB can use the PRIMARY KEY
		if( $i == 0 || $i == $setkey-1 )
		{
			$field->set_property( sql_index => 0 );
		}

		push @primary_key, $field;
	}

	my @indices;
	my @columns;
	foreach my $field (@fields)
	{
		if( $field->get_property( "sql_index" ) )
		{
			push @indices, [$field->get_sql_index()];
		}
		push @columns, $field->get_sql_type( $self->{session} );
	}
	
	@primary_key = map {
		$_->set_property( sql_index => 1 );
		$_->get_sql_index;
	} @primary_key;

	# Send to the database
	if( !$self->has_table( $tablename ) )
	{
		$rv &&= $self->_create_table( $tablename, \@primary_key, \@columns );
	}
	
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

=item $ok = $db->create_foreign_key( $main_table, $aux_table, $key_field )

Create a foreign key relationship between $main_table and $aux_table using the $key_field.

This will cause records in $aux_table to be deleted if the equivalent record is deleted from $main_table.

=cut

sub create_foreign_key
{
	my( $self, $main_table, $table, $key_field ) = @_;

	my $Q_key_name = $self->quote_identifier( $key_field->get_sql_name );
	my $Q_fk = $self->quote_identifier( $table . "_fk" );

	return $self->do(
		"ALTER TABLE ".$self->quote_identifier( $table ) .
		" ADD CONSTRAINT $Q_fk" .
		" FOREIGN KEY($Q_key_name)" .
		" REFERENCES ".$self->quote_identifier( $main_table )."($Q_key_name)" .
		" ON DELETE CASCADE"
	);
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
		"MAXVALUE 9223372036854775807 " . # 2^63 - 1
#		"MAXVALUE 999999999999999999999999999 " . # Oracle
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

=item $success = $db->drop_column( $table, $column )

Drops a column from a table.

=cut

sub drop_column
{
	my( $self, $table, $name ) = @_;

	if( $self->has_table( $table ) )
	{
		if( $self->has_column( $table, $name ) )
		{
			return defined $self->do("ALTER TABLE ".$self->quote_identifier( $table )." DROP COLUMN ".$self->quote_identifier( $name ));
		}
	}

	return 0;
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

	# Note: limit to 64 characters
	my $index_name = join('_', substr($columns[0], 0, 60), scalar @columns - 1 );

	my $sql = sprintf("CREATE INDEX %s ON %s (%s)",
		$self->quote_identifier( $index_name ),
		$self->quote_identifier( $table ),
		join(',',map { $self->quote_identifier($_) } @columns) );

	return defined $self->do($sql);
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
	my $index_name = substr(join("_",@columns),0,63);

	my $sql = "CREATE UNIQUE INDEX $index_name ON $table(".join(',',map { $self->quote_identifier($_) } @columns).")";

	return $self->do($sql);
}

######################################################################
=pod

=item $rows = $db->_update( $tablename, $keycols, $keyvals, $columns, @values )

UPDATES $tablename where $keycols equals $keyvals and returns the number of rows affected.

Note! If no rows are affected the result is still 'true', see DBI's execute() method.

This method is internal.

=cut
######################################################################

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

	if( $self->{debug} )
	{
		$self->{session}->get_repository->log( "Database execute debug: $sql" );
	}

	my $rv = 0;

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
			$self->{session}->log( Carp::longmess( $sth->{Statement} . ": " . $self->{dbh}->err ) );
			return $rc;
		}
		$rv += $rc; # otherwise add up the number of rows affected
	}

	$sth->finish;

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
	foreach my $row (@values)
	{
		my $i = 0;
		for(@$row)
		{
			$sth->bind_param( ++$i, ref($_) eq 'ARRAY' ? @$_ : $_ );
		}
		$rc &&= $sth->execute();
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
	my $keyname = $keyfield->get_sql_name;
	my $id = $data->{$keyname};

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

	if( $dataset->ordered )
	{
		EPrints::Index::insert_ordervalues( $self->{session}, $dataset, {
				$keyname => $id,
			});
	}

	# Now add the ACTUAL data:
	return $self->update( $dataset, $data, $data );
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

	return "NULL" if !defined $value || $value =~ /\D/;

	return $value+0;
}

=item $str = $db->quote_binary( $bytes )

Some databases (Oracle/PostgreSQL) require transforms of binary data to work correctly.

This method should be called on data containing nul bytes or back-slashes before being passed on L</quote_value>.

=cut

sub quote_binary
{
	return $_[1];
}

=item $str = $db->quote_ordervalue( $field, $value )

Some databases (Oracle) can't order by CLOBS so need special treatment when creating the ordervalues tables. This method allows any fixing-up required for string data before it's inserted.

=cut

sub quote_ordervalue
{
	return $_[2];
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

=item $success = $db->update( $dataset, $data, $changed )

Updates a record in the database with the given $data. The key field value must be given.

Updates the ordervalues if the dataset is L<ordered|EPrints::DataSet/ordered>.

=cut
######################################################################

sub update
{
	my( $self, $dataset, $data, $changed ) = @_;

	my $rv = 1;

	my $keyfield = $dataset->get_key_field();
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
		push @values, $field->sql_row_from_value( $self->{session}, $value );
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
				$multifield->sql_row_from_value( $self->{session}, $value )
			];
		}

		$rv &&= $self->insert( $auxtable, \@names, @rows );
	}

	if( $dataset->ordered )
	{
		EPrints::Index::update_ordervalues( $self->{session}, $dataset, $data, $changed );
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

	if( $dataset->indexable )
	{
		EPrints::Index::remove_all( $self->{session}, $dataset, $id );
	}

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

	my $repository = $self->{session}->get_repository;

	my $rc = 1;

	# Create the counters 
	foreach my $counter ($repository->get_sql_counter_ids)
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

	my $repository = $self->{session}->get_repository;

	foreach my $counter ($repository->get_sql_counter_ids)
	{
		$self->drop_counter( $counter );
	}

	return 1;
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
	my( $self, $userid, %opts ) = @_;

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
			my $doc = EPrints::XML::parse_xml_string( "<xml>$msg</xml>" );
			if( !EPrints::XML::is_dom( $doc, "Document" ) )
			{
				EPrints::abort "Expected Document node from parse_xml_string(), got '$doc' instead";
			}
			$content = $session->make_doc_fragment();
			foreach my $node ($doc->documentElement->childNodes)
			{
				$content->appendChild( $session->clone_for_me( $node, 1 ) );
			}
			EPrints::XML::dispose($doc);
		};
		if( !defined( $content ) )
		{
			$content = $session->make_doc_fragment();
			$content->appendChild( $session->make_text( "Internal error while parsing: $msg" ));
		}
		push @$messages, {
			type => $message->get_value( "type" ),
			content => $content,
		};

		$message->remove() if $opts{clear};
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
		$curval = $self->counter_next( $counter );
	}

	if( $curval < $value )
	{
		# Oracle/Postgres will complain if we try to set a zero-increment
		if( ($value-$curval-1) != 0 )
		{
			$self->do("ALTER SEQUENCE ".$self->quote_identifier($counter_seq)." INCREMENT BY ".($value-$curval-1));
		}
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
	$cachemap->create_sql_table( $dataset );

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
	my $keyfield = $dataset->get_key_field();
	my $keyname = $keyfield->get_sql_name();
	$logic ||= [];

	my $sql;
	$sql .= "SELECT ".$self->quote_identifier( $srctable, $keyname )." FROM ".$self->quote_identifier( $srctable );
	if( defined $order )
	{
		my $ov_table;
		if( $dataset->ordered )
		{
			$ov_table = $dataset->get_ordervalues_table_name( $self->{session}->get_langid );
		}
		else
		{
			$ov_table = $dataset->get_sql_table_name();
		}
		$sql .= " LEFT JOIN ".$self->quote_identifier($ov_table).$self->sql_AS.$self->quote_identifier( "O" );
		$sql .= " ON ".$self->quote_identifier( $srctable, $keyname )."=".$self->quote_identifier( "O", $keyname );
	}
	if( scalar @$logic )
	{
		$sql .= " WHERE ".join(" AND ", @$logic);
	}
	if( defined $order )
	{
		$sql .= " ORDER BY ";
		my @parts;
		foreach( split( "/", $order ) )
		{
			my $desc = 0;
			if( s/^-// ) { $desc = 1; }
			my $field = EPrints::Utils::field_from_config_string(
					$dataset,
					$_ );
			# if the dataset isn't ordered order by the individual columns of
			# the field
			if( $dataset->ordered )
			{
				push @parts, $self->quote_identifier("O", $field->name);
				$parts[-1] .= " DESC" if $desc;
			}
			else
			{
				foreach my $part ($field->get_sql_names)
				{
					push @parts, $self->quote_identifier("O", $part);
					$parts[-1] .= " DESC" if $desc;
				}
			}
		}
		$sql .= join ', ', @parts;
	}

	return $self->_cache_from_SELECT( $cachemap, $dataset, $sql );
}

sub _cache_from_SELECT
{
	my( $self, $cachemap, $dataset, $select_sql ) = @_;

	my $cache_table  = $cachemap->get_sql_table_name;
	my $Q_pos = $self->quote_identifier( "pos" );
	my $key_field = $dataset->get_key_field();
	my $Q_keyname = $self->quote_identifier($key_field->get_sql_name);

	my $sql = "";
	$sql .= "INSERT INTO ".$self->quote_identifier( $cache_table );
	$sql .= "($Q_pos, $Q_keyname)";
	# ROWNUM is one-indexed
	$sql .= " SELECT ROWNUM, $Q_keyname";
	$sql .= " FROM ($select_sql) ".$self->quote_identifier( "S" );

	$self->do( $sql );
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
specified by $conditions across the tables specified in the $tables
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

	return \@results;
}


######################################################################
=pod

=item $c = $db->drop_orphan_cache_tables

Drop tables called "cacheXXX" where XXX is an integer. Returns the number of tables dropped.

=cut
######################################################################

sub drop_orphan_cache_tables
{
	my( $self ) = @_;

	my $rc = 0;

	foreach my $name ($self->get_tables)
	{
		next unless $name =~ /^cache(\d+)$/;
		next if defined $self->get_cachemap( $1 );
		$self->{session}->get_repository->log( "Dropping orphaned cache table [$name]" );
		$self->drop_table( $name );
		++$rc;
	}

	return $rc;
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
	my( $self, $dataset, $id ) = @_;

	return undef if !defined $id;

	return ($self->get_dataobjs( $dataset, $id ))[0];
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

=item @ids = $db->get_cache_ids( $dataset, $cachemap, $offset, $count )

Returns a list of $count ids from $cache_id starting at $offset and in the order in the cachemap.

=cut

sub get_cache_ids
{
	my( $self, $dataset, $cachemap, $offset, $count ) = @_;

	my @ids;

	my $Q_pos = $self->quote_identifier( "pos" );

	my $sql = "SELECT ".$self->quote_identifier( $dataset->get_key_field->get_sql_name );
	$sql .= " FROM ".$self->quote_identifier( $cachemap->get_sql_table_name );
	$sql .= " WHERE $Q_pos > $offset";
	if( defined $count )
	{
		$sql .= " AND $Q_pos <= ".($offset+$count);
	}
	$sql .= " ORDER BY ".$self->quote_identifier( "pos" )." ASC";

	my $sth = $self->prepare( $sql );
	$self->execute( $sth, $sql );

	while(my $row = $sth->fetch)
	{
		push @ids, $row->[0];
	}

	return @ids;
}

=item @dataobjs = $db->get_dataobjs( $dataset [, $id [, $id ] ] )

Retrieves the records in $dataset with the given $id(s). If an $id doesn't exist in the database it will be ignored.

=cut

sub get_dataobjs
{
	my( $self, $dataset, @ids ) = @_;

	return () unless scalar @ids;

	my @data = map { {} } @ids;

	my $session = $self->{session};

	my $key_field = $dataset->get_key_field;
	my $key_name = $key_field->get_name;

	# we build a list of OR statements to retrieve records
	my $Q_key_name = $self->quote_identifier( $key_name );
	my $logic = "";
	if( $key_field->isa( "EPrints::MetaField::Int" ) )
	{
		$logic = $Q_key_name . " IN (".join(',',map { $self->quote_int($_) } @ids).")";
	}
	else
	{
		$logic = $Q_key_name . " IN (".join(',',map { $self->quote_value($_) } @ids).")";
	}

	# we need to map the returned rows back to the input order
	my $i = 0;
	my %lookup = map { $_ => $i++ } @ids;

	# work out which fields we need to retrieve
	my @fields;
	my @aux_fields;
	foreach my $field ($dataset->get_fields)
	{
		next if $field->is_virtual;
		# never retrieve secrets
		next if $field->isa( "EPrints::MetaField::Secret" );

		if( $field->get_property( "multiple" ) )
		{
			push @aux_fields, $field;
		}
		else
		{
			push @fields, $field;
		}
	}

	# retrieve the data from the main dataset table
	my $sql = "SELECT ".join(',',map {
			$self->quote_identifier($_)
		} map {
			$_->get_sql_names
		} @fields);
	$sql .= " FROM ".$self->quote_identifier($dataset->get_sql_table_name);
	$sql .= " WHERE $logic";

	my $sth = $self->prepare( $sql );
	$self->execute( $sth, $sql );

	while(my @row = $sth->fetchrow_array)
	{
		my $epdata = {};
		foreach my $field (@fields)
		{
			$epdata->{$field->{name}} = $field->value_from_sql_row( $session, \@row );
		}
		next if !defined $epdata->{$key_name};
		$data[$lookup{$epdata->{$key_name}}] = $epdata;
	}

	# retrieve the data from multiple fields
	my $pos_field = EPrints::MetaField->new(
		repository => $session->get_repository,
		name => "pos",
		type => "int" );
	foreach my $field (@aux_fields)
	{
		my @fields = ($key_field, $pos_field, $field);
		my $sql = "SELECT ".join(',',map {
				$self->quote_identifier($_)
			} map {
				$_->get_sql_names
			} @fields);
		$sql .= " FROM ".$self->quote_identifier($dataset->get_sql_sub_table_name( $field ));
		$sql .= " WHERE $logic";

		# multiple values are always at least empty list
		foreach my $epdata (@data)
		{
			$epdata->{$field->{name}} = [];
		}

		my $sth = $self->prepare( $sql );
		$self->execute( $sth, $sql );
		while(my @row = $sth->fetchrow_array)
		{
			my( $id, $pos ) = splice(@row,0,2);
			my $value = $field->value_from_sql_row( $session, \@row );
			$data[$lookup{$id}]->{$field->{name}}->[$pos] = $value;
		}
	}

	# remove any objects that couldn't be retrieved
	@data = grep { defined $_->{$key_name} } @data;

	# convert the epdata into objects
	foreach my $epdata (@data)
	{
		# this avoids a lot of calls to MetaField::set_value()
		my $dataobj = $dataset->make_dataobj( {} );
		$dataobj->{data} = $epdata;
		$epdata = $dataobj;
	}

	return @data;
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

	my @aux = ();

	my $Q_table = $self->quote_identifier($dataset->get_sql_table_name());
	my $M = $self->quote_identifier("M"); # main table
	my $C = $self->quote_identifier("C"); # cache table
	my $A = $self->quote_identifier("A"); # aux table
	my $Q_pos = $self->quote_identifier("pos");

	my( @cols, @tables, @logic, @order );
	push @tables, "$Q_table $M";

	# inbox,buffer,archive etc.
	if( $dataset->id ne $dataset->confid )
	{
		my $ds_field = $dataset->get_field( $dataset->get_dataset_id_field() );
		my $Q_ds_field = $self->quote_identifier($ds_field->get_sql_name());
		push @logic, "$M.$Q_ds_field = ".$self->quote_value($dataset->id);
	}

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

		push @cols, map {
			"$M.".$self->quote_identifier($_)
		} $field->get_sql_names;
	}

	if ( $mode == 0 )
	{
		push @logic, "$M.$Q_keyname = ".$self->quote_value( $param );
	}
	elsif ( $mode == 1 )	
	{
		push @tables, $self->quote_identifier($param)." $C";
		push @logic, "$M.$Q_keyname = $C.$Q_keyname";
	}
	elsif ( $mode == 2 )	
	{
	}
	elsif ( $mode == 3 )	
	{
		push @tables, $self->quote_identifier($param)." $C";
		push @logic,
			"$M.$Q_keyname = $C.$Q_keyname",
			"$C.$Q_pos > ".$offset;
		if( $ntoreturn > 0 )
		{
			push @logic, "$C.$Q_pos <= ".($offset+$ntoreturn);
		}
		push @order, "$C.$Q_pos";
	}
	my $sql = "SELECT ".join(",",@cols)." FROM ".join(",",@tables);
	if( scalar(@logic) )
	{
		$sql .= " WHERE ".join(" AND ",@logic);
	}
	if( scalar(@order) )
	{
		$sql .= " ORDER BY ".join(",",@order);
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
		my( $sql, @cols, @tables, @logic, @order );

		my $Q_subtable = $self->quote_identifier($dataset->get_sql_sub_table_name( $multifield ));
		push @tables, "$Q_subtable $A";

		# inbox,buffer,archive etc.
		if( $dataset->id ne $dataset->confid )
		{
			my $ds_field = $dataset->get_field( $dataset->get_dataset_id_field() );
			my $Q_ds_field = $self->quote_identifier($ds_field->get_sql_name());
			push @tables, "$Q_table $M";
			push @logic,
				"$M.$Q_keyname = $A.$Q_keyname",
				"$M.$Q_ds_field = ".$self->quote_value($dataset->id);
		}

		push @cols,
			"$A.$Q_keyname",
			"$A.$Q_pos",
			map {
				"$A.".$self->quote_identifier($_)
			} $multifield->get_sql_names;
		if( $mode == 0 )	
		{
			push @logic, "$A.$Q_keyname = ".$self->quote_value( $param );
		}
		elsif( $mode == 1)
		{
			push @tables, $self->quote_identifier( $param )." $C";
			push @logic, "$A.$Q_keyname = $C.$Q_keyname";
		}	
		elsif( $mode == 2)
		{
		}
		elsif ( $mode == 3 )	
		{
			push @tables, $self->quote_identifier( $param )." $C";
			push @logic,
				 "$A.$Q_keyname = $C.$Q_keyname",
				 "$C.$Q_pos > ".$offset;
			if( $ntoreturn > 0 )
			{
				push @logic, "$C.$Q_pos <= ".($offset+$ntoreturn);
			}
			push @order, "$C.$Q_pos";
		}
		$sql = "SELECT ".join(",",@cols)." FROM ".join(",",@tables);
		if( scalar(@logic) )
		{
			$sql .= " WHERE ".join(" AND ",@logic);
		}
		if( scalar(@order) )
		{
			$sql .= " ORDER BY ".join(",",@order);
		}
		$sth = $self->prepare( $sql );
		$self->execute( $sth, $sql );
		while( my @values = $sth->fetchrow_array ) 
		{
			my( $id, $pos ) = splice(@values,0,2);
			my $n = $lookup{ $id };
			next unless defined $n; # junk data in auxiliary tables?
			$data[$n]->{$fn}->[$pos] = 
				$multifield->value_from_sql_row( $self->{session}, \@values );
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

	my $searchexp = $dataset->prepare_search();
	my( $values, $counts ) = $searchexp->perform_groupby( $field );

	return $values;
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
		$ofield->get_sql_type( $session ),
	]);

	# insert all the order values with their index in $values
	my @pairs;
	my $i = 0;
	foreach my $value (@$values)
	{
		push @pairs, [
			$i++,
			$field->ordervalue_single( $value, $session, $langid )
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

	return $dataset->prepare_search( %opts )->perform_distinctby( [$field] );
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

		return undef unless( $self->retry_error() );

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

		# DB disconnect?
		unless( $self->retry_error() )
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

=item $sth = $db->prepare_select( $sql [, %options ] )

Prepare a SELECT statement $sql and return a handle to it. After preparing a
statement use execute() to execute it.

The LIMIT SQL keyword is not universally supported, to specify a LIMIT you must
use the B<limit> option.

Options:

	limit - limit the number of rows returned
	offset - return B<limit> number of rows after offset

=cut
######################################################################

sub prepare_select
{
	my( $self, $sql, %options ) = @_;

	if( defined $options{limit} && length($options{limit}) )
	{
		if( defined $options{offset} && length($options{offset}) )
		{
			$sql .= sprintf(" LIMIT %d OFFSET %d",
				$options{limit},
				$options{offset} );
		}
		else
		{
			$sql .= sprintf(" LIMIT %d", $options{limit} );
		}
	}

	return $self->prepare( $sql );
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

	$rc &&= $self->has_dataset_index_tables( $dataset );

	return $rc;
}

sub has_dataset_index_tables
{
	my( $self, $dataset ) = @_;

	return 1 if !$dataset->indexable;

	my $table = $dataset->get_sql_rindex_table_name;
	return 0 if !$self->has_table( $table );

	return 0 if !defined($self->index_name(
		$table,
		$dataset->get_key_field->get_sql_name,
		"field"
	));

	return 1;
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

	# Check the field index
	$rc &&= $self->_has_field_index( $dataset, $field );

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

=item $db->add_field( $dataset, $field [, $force ] )

Add $field to $dataset's tables.

If $force is true will modify/replace an existing column (use with care!).

=cut
######################################################################

sub add_field
{
	my( $self, $dataset, $field, $force ) = @_;

	my $rc = 1;

	# If this field is virtual and has sub-fields, add them
	if( $field->isa( "EPrints::MetaField::Compound" ) )
	{
		my $sub_fields = $field->get_property( "fields_cache" );
		foreach my $sub_field (@$sub_fields)
		{
			$rc &&= $self->add_field( $dataset, $sub_field, $force );
		}
	}
	else # Add the field itself to the metadata table
	{
		$rc &&= $self->_add_field( $dataset, $field, $force );
	}

	# Add the field to order values (used to order search results)
	$rc &&= $self->_add_field_ordervalues( $dataset, $field );

	# Add the index to the field
	$rc &&= $self->_add_field_index( $dataset, $field );

	return $rc;
}

# Split a sql type definition into its constituent columns
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

	my $sql_field = $field->create_ordervalues_field( $self->{session}, $langid );

	my( $col ) = $sql_field->get_sql_type( $self->{session} );

	return $self->do( "ALTER TABLE ".$self->quote_identifier($order_table)." ADD $col" );
}

sub _has_field_index
{
	my( $self, $dataset, $field ) = @_;

	return 1 if $field->is_virtual;

	return 1 if !$field->get_property( "sql_index" );

	my $table;
	if( $field->get_property( "multiple" ) )
	{
		$table = $dataset->get_sql_sub_table_name( $field );
	}
	else
	{
		$table = $dataset->get_sql_table_name;
	}

	my @cols = $field->get_sql_index;

	# see if it's already part of a PRIMARY KEY
	my @primary_key = $self->get_primary_key( $table );
	if( @primary_key && $primary_key[0] eq $cols[0] )
	{
		return 1;
	}

	my $index_name = $self->index_name( $table, @cols );

	return defined $index_name;
}

# Add the index to the field
sub _add_field_index
{
	my( $self, $dataset, $field ) = @_;

	return 1 if $field->is_virtual;

	return 1 if !$field->get_property( "sql_index" );

	return 1 if $self->_has_field_index( $dataset, $field );

	my $table;
	if( $field->get_property( "multiple" ) )
	{
		$table = $dataset->get_sql_sub_table_name( $field );
	}
	else
	{
		$table = $dataset->get_sql_table_name;
	}

	my @cols = $field->get_sql_index;

	return $self->create_index( $table, @cols );
}

# Add the field to the main tables
sub _add_field
{
	my( $self, $dataset, $field, $force ) = @_;

	my $rc = 1;

	return $rc if $field->is_virtual; # Virtual fields are still added to ordervalues???

	if( $field->get_property( "multiple" ) )
	{
		return $self->_add_multiple_field( $dataset, $field, $force );
	}

	my $table = $dataset->get_sql_table_name;
	my @names = $field->get_sql_names;
	my @types = $field->get_sql_type( $self->{session} );

	return $rc if $self->has_column( $table, $names[0] ) && !$force;

	for(my $i = 0; $i < @names; ++$i)
	{
		if( $self->has_column( $table, $names[$i] ) )
		{
			$types[$i] = "MODIFY $types[$i]";
		}
		else
		{
			$types[$i] = "ADD $types[$i]";
		}
	}
	
	$rc &&= $self->do( "ALTER TABLE ".$self->quote_identifier($table)." ".join(",", @types));

	if( my @columns = $field->get_sql_index )
	{
		$rc &&= $self->create_index( $table, @columns );
	}

	return $rc;
}

# Add a multiple field to the main tables
sub _add_multiple_field
{
	my( $self, $dataset, $field, $force ) = @_;

	my $table = $dataset->get_sql_sub_table_name( $field );
	
	# modify the existing table
	if( $self->has_table( $table ) )
	{
		return 1 unless $force;

		my @names = $field->get_sql_names;
		my @types = $field->get_sql_type( $self->{session} );
		for(my $i = 0; $i < @names; ++$i)
		{
			if( $self->has_column( $table, $names[$i] ) )
			{
				$types[$i] = "MODIFY $types[$i]";
			}
			else
			{
				$types[$i] = "ADD $types[$i]";
			}
		}
		return $self->do( "ALTER TABLE ".$self->quote_identifier( $table )." ".join(",", @types) );
	}

	my $key_field = $dataset->get_key_field();

	my $pos_field = EPrints::MetaField->new(
		repository => $self->{ session }->get_repository,
		name => "pos",
		type => "int" );

	return $self->_create_table(
		$table,
		[ # primary key
			$key_field->get_sql_name,
			$pos_field->get_sql_name
		],
		[ # columns
			$key_field->get_sql_type( $self->{session} ),
			$pos_field->get_sql_type( $self->{session} ),
			$field->get_sql_type( $self->{session} )
		] );
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
	if( $field->isa( "EPrints::MetaField::Compound" ) )
	{
		my $sub_fields = $field->get_property( "fields_cache" );
		foreach my $sub_field (@$sub_fields)
		{
			$self->remove_field( $dataset, $sub_field );
		}
	}
	elsif( $field->is_virtual )
	{
		return; # isn't in the database
	}
	else # Remove the field itself from the metadata table
	{
		$self->_remove_field( $dataset, $field );
	}

	# Remove the field from order values (used to order search results)
	$self->_remove_field_ordervalues( $dataset, $field );

	return 1; # if we failed the field probably isn't there anyway
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

	$self->drop_column(
		$dataset->get_ordervalues_table_name( $langid ),
		$field->get_sql_name );
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
		$rc &&= $self->drop_column(
			$dataset->get_sql_table_name(),
			$_ );
	}

	return $rc;
}

# Remove a multiple field from the main tables
sub _remove_multiple_field
{
	my( $self, $dataset, $field ) = @_;

	my $table = $dataset->get_sql_sub_table_name( $field );

	$self->drop_table( $table );
}

######################################################################
=pod

=item $ok = $db->rename_field( $dataset, $field, $old_name )

Rename a $field in the database from it's old name $old_name.

Returns true if the field was successfully renamed.

=cut
######################################################################

sub rename_field
{
	my( $self, $dataset, $field, $old_name ) = @_;

	my $rc = 1;

	# If this field is virtual and has sub-fields, rename them
	if( $field->is_virtual )
	{
		my $sub_fields = $field->get_property( "fields_cache" );
		foreach my $sub_field (@$sub_fields)
		{
			my $sub_name = $sub_field->get_property( "sub_name" );
			$sub_field->{parent_name} = $field->get_name;
			$sub_field->{name} = $field->get_name . "_" . $sub_name;
			$rc &&= $self->rename_field( $dataset, $sub_field, $old_name . "_" . $sub_name );
		}
	}
	else # rename the field itself from the metadata table
	{
		$rc &&= $self->_rename_field( $dataset, $field, $old_name );
	}

	# rename the field from order values (used to order search results)
	$rc &&= $self->_rename_field_ordervalues( $dataset, $field, $old_name );

	return $rc;
}

# rename the ordervalues table column
sub _rename_field_ordervalues
{
	my( $self, $dataset, $field, $old_name ) = @_;

	my $rc = 1;

	foreach my $langid ( @{$self->{ session }->get_repository->get_conf( "languages" )} )
	{
		$rc &&= $self->_rename_field_ordervalues_lang( $dataset, $field, $old_name, $langid );
	}

	return $rc;
}

sub _rename_field_ordervalues_lang
{
	my( $self, $dataset, $field, $old_name, $langid ) = @_;

	my $order_table = $dataset->get_ordervalues_table_name( $langid );

	my $sql = sprintf("ALTER TABLE %s RENAME COLUMN %s TO %s",
			$self->quote_identifier($order_table),
			$self->quote_identifier($old_name),
			$self->quote_identifier($field->get_sql_name)
		);

	return $self->do( $sql );
}

# rename a field
sub _rename_field
{
	my( $self, $dataset, $field, $old_name ) = @_;

	my $rc = 1;

	return $rc if $field->is_virtual; # Virtual fields are still added to ordervalues

	if( $field->get_property( "multiple" ) )
	{
		return $self->_rename_multiple_field( $dataset, $field, $old_name );
	}

	my $table = $dataset->get_sql_table_name;
	$rc &&= $self->_rename_table_field( $table, $field, $old_name );

	return $rc;
}

# rename a multiple field (i.e. rename the table & column)
sub _rename_multiple_field
{
	my( $self, $dataset, $field, $old_name ) = @_;

	my $rc = 1;

	my $table = $dataset->get_sql_sub_table_name( $field );

	# work out what the old table is called
	my $old_table;
	{
		local $field->{name} = $old_name;
		$old_table = $dataset->get_sql_sub_table_name( $field );
	}

	$rc &&= $self->_rename_table_field( $old_table, $field, $old_name );

	# rename the table
	$rc &&= $self->do( "ALTER TABLE ".$self->quote_identifier($old_table)." RENAME TO ".$self->quote_identifier($table) );
}

# utility method to rename a field column in a given table
sub _rename_table_field
{
	my( $self, $table, $field, $old_name ) = @_;

	my $rc = 1;

	my @names = $field->get_sql_names;

	# work out what the old columns are called
	my @old_names;
	{
		local $field->{name} = $old_name;
		@old_names = $field->get_sql_names;
	}

	my @column_sql;
	for(my $i = 0; $i < @names; ++$i)
	{
		push @column_sql, sprintf("RENAME COLUMN %s TO %s",
				$self->quote_identifier($old_names[$i]),
				$self->quote_identifier($names[$i])
			);
	}
	
	$rc &&= $self->do( "ALTER TABLE ".$self->quote_identifier($table)." ".join(",", @column_sql));

	return $rc;
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

	my $version = EPrints::MetaField->new(
		repository => $self->{ session },
		name => $column,
		type => "text",
		maxlength => 64,
		allow_null => 0 );

	$self->drop_table( $table ); # sanity check
	$self->create_table( $table, 1, $version );

	$self->insert( $table, [$column], ["0.0.0"] );
}

######################################################################
=pod

=item $db->drop_version_table

Drop the version table.

=cut
######################################################################

sub drop_version_table
{
	my( $self ) = @_;

	$self->drop_table( "version" );
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

=item $name = $db->index_name( $table, @columns )

Returns the name of the first index that starts with @columns on the $table table.

Returns undef if no index exists.

=cut

sub index_name
{
	my( $self, $table, @cols ) = @_;

	my $sql = "SELECT S0.index_name FROM ";
	my $t = "information_schema.statistics";
	my @logic;
	foreach my $i (0..$#cols)
	{
		$sql .= ", " if $i > 0;
		$sql .= $t.$self->sql_AS."S$i";
		push @logic,
			"S0.index_name=S$i.index_name",
			"S$i.table_schema=".$self->quote_value( $self->{session}->config( "dbname" ) ),
			"S$i.table_name=".$self->quote_value( $table ),
			"S$i.column_name=".$self->quote_value( $cols[$i] ),
			"S$i.seq_in_index=".($i+1);
	}
	$sql .= " WHERE " . join ' AND ', @logic;

	my( $index_name ) = $self->{dbh}->selectrow_array( $sql );

	return $index_name;
}

######################################################################
=pod

=item $db->drop_table( $tablename [, $tablename2 ] )

Delete the named table(s). Use with caution!

=cut
######################################################################
	
sub drop_table
{
	my( $self, @tables ) = @_;

	local $self->{dbh}->{PrintError} = 0;
	local $self->{dbh}->{RaiseError} = 0;

	my $sql = "DROP TABLE ".join(',',
			map { $self->quote_identifier($_) } @tables
		)." CASCADE";

	return defined $self->{dbh}->do( $sql );
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

Return the version of eprints which the database is compatible with
or undef if unknown (before v2.1).

=cut
######################################################################

sub get_version
{
	my( $self ) = @_;

	local $self->{dbh}->{PrintError} = 0;
	local $self->{dbh}->{RaiseError} = 0;

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

# This is a hacky method to support CI username/email lookups. Should be
# implemented as an option on searching (bigger change of search mechanisms?).

sub ci_lookup
{
	my( $self, $field, $value ) = @_;

	my $table = $field->dataset->get_sql_table_name;
	
	my $sql =
		"SELECT ".$self->quote_identifier( $field->get_sql_name ).
		" FROM ".$self->quote_identifier( $table ).
		" WHERE LOWER(".$self->quote_identifier( $field->get_sql_name ).")=LOWER(".$self->quote_value( $value ).")";

	my $sth = $self->prepare( $sql );
	$sth->execute;

	my( $real_value ) = $sth->fetchrow_array;

	$sth->finish;

	return defined $real_value ? $real_value : $value;
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

	$username = $self->ci_lookup( $self->{session}->dataset( "user" )->field( "username" ), $username );

	my $Q_password = $self->quote_identifier( "password" );
	my $Q_table = $self->quote_identifier( "user" );
	my $Q_username = $self->quote_identifier( "username" );

	my $sql = "SELECT $Q_username, $Q_password FROM $Q_table WHERE $Q_username=".$self->quote_value($username);

	my $sth = $self->prepare( $sql );
	$self->execute( $sth , $sql );
	my( $real_username, $crypt ) = $sth->fetchrow_array;
	$sth->finish;

	return undef if( !defined $crypt );

	return EPrints::Utils::crypt_equals( $crypt, $password ) ?
		$real_username :
		undef;
}


######################################################################
=pod

=item $db->secret_matches( $dataobj, $fieldname, $token [, $callback ] )

Returns whether the clear-text $token matches the stored crypted field
for the $dataobj according to $callback.

If not given, $callback defaults to L<EPrints::Utils::crypt_equals>

=cut
######################################################################

sub secret_matches
{
	my( $self, $dataobj, $fieldname, $token, $callback ) = @_;

	my $dataset = $dataobj->dataset();

	# Build and execute SQL
	my $Q_token = $self->quote_identifier( $fieldname );
	my $Q_table = $self->quote_identifier( $dataset->base_id() );
	my $Q_dataobj_id = $self->quote_identifier( $dataset->base_id() . 'id' );

	my $sql = "SELECT $Q_token FROM $Q_table WHERE $Q_dataobj_id = " . $self->quote_value( $dataobj->id );

	my $sth = $self->prepare( $sql );
	$self->execute( $sth , $sql );
	my ( $real_token ) = $sth->fetchrow_array;
	$sth->finish;

	return undef if( !defined $real_token );

	# Test provided token
	if( defined $callback )
	{
		no strict 'refs';
		return &{$callback}( $real_token, $token );
	}

	return EPrints::Utils::crypt_equals( $real_token, $token );

}


######################################################################
=pod

=item $db->is_secret_set( $dataobj, $fieldname )

Returns 1 if the secret $fieldname in $dataobj has a value set.
Otherwise returns 0.

=cut
######################################################################

sub is_secret_set
{
	my( $self, $dataobj, $fieldname ) = @_;

	# Build and execute SQL
	my $dataset = $dataobj->dataset();
	my $ds_baseid = $dataset->base_id();
	my $Q_id = $self->quote_identifier( $ds_baseid . 'id' );
	my $Q_token = $self->quote_identifier( $fieldname );
	my $Q_table = $self->quote_identifier( $ds_baseid );
	my $Q_dataobj_id = $self->quote_identifier( $ds_baseid . 'id' );

	my $sql = "SELECT $Q_id FROM $Q_table WHERE $Q_dataobj_id = " . $self->quote_value( $dataobj->id ) . " AND $Q_token IS NOT NULL";

	my $sth = $self->prepare( $sql );
	$self->execute( $sth , $sql );
	my( $matched_id ) = $sth->fetchrow_array;
	$sth->finish;

	return ( defined $matched_id ) ? 1 : 0;
}


######################################################################
=pod

=item $version = $db->get_server_version

Return the database server version.

=cut
######################################################################

sub get_server_version {}

######################################################################
=pod

=item $charset = $db->get_default_charset( LANGUAGE )

Return the character set to use for LANGUAGE.

Returns undef if character sets are unsupported.

=cut
######################################################################

sub get_default_charset {}

######################################################################
=pod

=item $collation = $db->get_default_collation( LANGUAGE )

Return the collation to use for LANGUAGE.

Returns undef if collation is unsupported.

=cut
######################################################################

sub get_default_collation {}

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

=pod

=for INTERNAL

=item @events = $db->dequeue_events( $n )

Attempt to dequeue up to $n events. May return between 0 and $n events depending on parallel processes and how many events are remaining on the queue.

=cut

sub dequeue_events
{
	my( $self, $n ) = @_;

	my $session = $self->{session};
	my $dataset = $session->dataset( "event_queue" );

	my $until = EPrints::Time::get_iso_timestamp();

	my @events;

	my @potential = $dataset->search(
			filters => [
				{ meta_fields => ["status"], value => "waiting" },
				{ meta_fields => ["start_time"], value => "..$until", match => "EQ" },
			],
			custom_order => "-priority/-start_time",
			limit => $n,
		)->slice( 0, $n );

	my $sql = "UPDATE ".
		$self->quote_identifier( $dataset->get_sql_table_name ).
		" SET ".
		$self->quote_identifier( $dataset->field( "status" )->get_sql_name ).
		"=".
		$self->quote_value( "inprogress" ).
		" WHERE ".
		$self->quote_identifier( $dataset->key_field->get_sql_name ).
		"=?".
		" AND ".
		$self->quote_identifier( $dataset->field( "status" )->get_sql_name ).
		"=".
		$self->quote_value( "waiting" );

	foreach my $event (@potential)
	{
		my $rows = $self->{dbh}->do( $sql, {}, $event->id );
		if( $rows == -1 )
		{
			EPrints::abort( "Error in SQL: $sql\n".$self->{dbh}->{errstr} );
		}
		elsif( $rows == 1 )
		{
			$event->set_value( "status", "inprogress" );
			push @events, $event;
		}
		else
		{
			# another process grabbed this event
		}
	}

	return @events;
}

=item $sql = $db->prepare_regexp( $quoted_column, $quoted_value )

The syntax used for regular expressions varies across databases. This method takes two B<quoted> values and returns a SQL expression that will apply the regexp ($quoted_value) to the column ($quoted_column).

=cut

sub prepare_regexp
{
	my( $self, $col, $value ) = @_;

	return "$col REGEXP $value";
}

=item $sql = $db->sql_AS()

Returns the syntactic glue to use when aliasing. SQL 92 DBs will happilly use " AS " but some DBs (Oracle!) won't accept it.

=cut

sub sql_AS
{
	my( $self ) = @_;

	return " AS ";
}

=item $sql = $db->sql_LIKE()

Returns the syntactic glue to use when making a case-insensitive LIKE. PostgreSQL requires "ILIKE" while everything else uses "LIKE" and the column collation.

=cut

sub sql_LIKE
{
	my( $self ) = @_;

	return " LIKE ";
}

sub retry_error
{
	return 0;
}

sub duplicate_error
{
	return 0;
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

