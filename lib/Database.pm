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
use EPrints::Deletion;
use EPrints::EPrint;
use EPrints::Log;
use EPrints::Subscription;
use EPrints::Constants;

#
# Table names
#

#
# Seperator - used to join parts of the name of a table
#
my $SEPERATOR = "_";

#
# Counters
#
@EPrints::Database::counters = ( "eprintid" );


#
#
# ID of next buffer table. This can safely reset to zero each time
# The module restarts as it is only used for temporary tables.
#
my $NEXTBUFFER = 0;

######################################################################
#
# build_connection_string()
#
#  Build the string to use to connect via DBI
#
######################################################################

sub build_connection_string
{
	my( %params ) = @_;

        # build the connection string
        my $dsn = "DBI:mysql:database=$params{db_name}";
        if( defined $params{db_host} )
        {
                $dsn.= ";host=".$params{db_host};
        }
        if( defined $params{db_port} )
        {
                $dsn.= ";port=".$params{db_port};
        }
        if( defined $params{db_sock} )
        {
                $dsn.= ";socket=".$params{db_sock};
        }
print STDERR ">>$dsn\n";
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
	my( $class , $session) = @_;

	my $self = {};
	bless $self, $class;
	$self->{session} = $session;

	# Connect to the database
	$self->{dbh} = DBI->connect( build_connection_string( 
					db_host => $session->{site}->getConf("db_host"),
					db_sock => $session->{site}->getConf("db_sock"),
					db_port => $session->{site}->getConf("db_port"),
					db_name => $session->{site}->getConf("db_name") ),
	                             $session->{site}->getConf("db_user"),
	                             $session->{site}->getConf("db_pass"),
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
	
	my $success = 1;

	foreach( "user" , "inbox" , "buffer" , "archive" ,
		 "document" , "subject" , "subscription" , "deletion" )
	{
		$success = $success && $self->_create_table( 
			$self->{session}->getSite()->getDataSet( $_ ) );
	}

	#$success = $success && $self->_create_tempmap_table();
	#$success = $success && $self->_create_counter_table();
	
	return( $success );
}
		


######################################################################
#
# $success = _create_table( $name, @fields )
#
#  Create a database table with the given name, and columns specified
#  in @fields, which is an array of MetaField types.
#
#  The aux. function has an extra parameter which means the table
#  has no primary key, this is for purposes of recursive table 
#  creation (aux. tables have no primary key)
#
######################################################################

sub _create_table
{
	my( $self, $dataset ) = @_;
	
	my $rv = 1;

	my $keyfield = $dataset->getKeyField()->clone();

	$keyfield->{indexed} = 1;
	my $fieldword = EPrints::MetaField->new( 
		undef,
		{ 
			name => "fieldword", 
			type => "text"
		} );

	$rv = $rv & $self->_create_table_aux(
			$dataset->getSQLIndexTableName(),
			$dataset,
			0, # no primary key
			( $keyfield , $fieldword ) );

	$rv = $rv && $self->_create_table_aux( 
				$dataset->getSQLTableName(), 
				$dataset, 
				1, 
				$dataset->getFields() );

	return $rv;
}

sub _create_table_aux
{
	my( $self, $tablename, $dataset, $setkey, @fields ) = @_;
	
	my $field;
	my $rv = 1;

	# Construct the SQL statement
	my $sql = "CREATE TABLE $tablename (";
	my $key = undef;
	my @indices;
	my $first = 1;
	# Iterate through the columns
	foreach $field (@fields)
	{
		if ( $field->isMultiple() )
		{ 	
			# make an aux. table for a multiple field
			# which will contain the same type as the
			# key of this table paired with the non-
			# multiple version of this field.
			# auxfield and keyfield must be indexed or 
			# there's not much point. 
			my $auxfield = $field->clone();
			$auxfield->setMultiple( 0 );
			my $keyfield = $dataset->getKeyField()->clone();
			$keyfield->setIndexed( 1 );
			my $pos = EPrints::MetaField->new( 
				undef,
				{ 
					name => "pos", 
					type => "int",
				} );
			my @auxfields = ( $keyfield, $pos, $auxfield );
			my $rv = $rv && $self->_create_table_aux(	
				$dataset->getSQLSubTableName( $field ),
				$dataset,
				0, # no primary key
				@auxfields );
			next;
		}
		if ( $first )
		{
			$first = 0;
		} 
		else 
		{
			$sql .= ", ";
		}
		my $part = $field->get_sql_type();
		my %bits = (
			 "name"=>$field->{name},
			 "param"=>"" );

			
		# First field is primary key.
		if( !defined $key && $setkey)
		{
			$key = $field;
			$bits{"param"} = "NOT NULL";
		}
		elsif( $field->{indexed} )
		{
			$bits{"param"} = "NOT NULL";
			my $index = $field->get_sql_index();
	
			while( $index =~ s/\$\(([a-z]+)\)/$bits{$1}/e ) { ; }
			push @indices, $index;
		}
		while( $part =~ s/\$\(([a-z]+)\)/$bits{$1}/e ) { ; }
		$sql .= $part;

	}
	if ( $setkey )	
	{
		$sql .= ", PRIMARY KEY ($key->{name})";
	}

	
	foreach (@indices)
	{
		$sql .= ", $_";
	}
	
	$sql .= ");";
	
#EPrints::Log::debug( "Database", "SQL: $sql" );

	# Send to the database
	$rv = $rv && $self->do( $sql );
	
	# Return with an error if unsuccessful
	return( defined $rv );
}


######################################################################
#
# $success = add_record( $table, $data )
#
#  Add data to the given table. 
#
#
######################################################################

sub add_record
{
	my( $self, $dataset, $data ) = @_;

	my $table = $dataset->getSQLTableName();
	
	my $keyfield = $dataset->getKeyField();

	my $sql = "INSERT INTO ".$dataset->getSQLTableName()." ";
	$sql   .= " (".$dataset->getKeyField()->getName().") ";
	$sql   .= "VALUES (\"".prep_value($data->{$dataset->getKeyField()->getName()})."\")";

	# Send to the database
	my $rv = $self->do( $sql );

	# Now add the ACTUAL data:
	$self->update( $dataset , $data );
	
	# Return with an error if unsuccessful
	return( defined $rv );
}

######################################################################
#
# $munged = _escape_chars( $value )
#
#  Modify value such that " becomes \" and \ becomes \\ [STATIC]
#
######################################################################

sub _escape_chars
{
	my( $value ) = @_; 
	$value =~ s/["\\.'%]/\\$&/g;
	return $value;
}

######################################################################
#
# $munged = prep_value( $value )
#
#  Call _escape_chars on value. If value is not defined return
#  an empty string instead. [STATIC]
#
######################################################################

sub prep_value
{
	my( $value ) = @_; 
	
	if( !defined $value )
	{
		return "";
	}
	
	return _escape_chars( $value );
}

######################################################################
#
# $success = update( $table, $key_field, $key_value, $data )
#
#  Update the row where $key_field is $key_value, in $table, with
#  the given values. Dosn't handle aux fields (yet).
#  key_field MUST NOT be a multiple type.
#
######################################################################

sub update
{
	my( $self, $dataset, $data ) = @_;

	my $rv = 1;
	my $sql;

	my @fields = $dataset->getFields();

	# skip the keyfield;
	my $keyfield = $dataset->getKeyField();

	my $keyvalue = prep_value($data->{$keyfield->getName()});

	# The same WHERE clause will be used a few times, so lets define
	# it now:
	my $where = $keyfield->getName()." = \"$keyvalue\"";

	my $indextable = $dataset->getSQLIndexTableName();
	$sql = "DELETE FROM $indextable WHERE $where";
	$rv = $rv && $self->do( $sql );

	my @aux;
	my %values = ();

	foreach( @fields ) 
	{
		if( $_->isMultiple() ) 
		{ 
			push @aux,$_;
		}
		else 
		{
			# clearout the freetext search index table for this field.

			if( $_->isType( "name" ) )
			{
				$values{$_->getName()."_given"} = 
					$data->{$_->getName()}->{given};
				$values{$_->getName()."_family"} = 
					$data->{$_->getName()}->{family};
			}
			else
			{
				$values{$_->getName()} =
					$data->{$_->getName()};
			}
			if( $_->isTextIndexable() )
			{ 
				$self->_freetext_index( $dataset, $keyvalue, $_, $data->{$_->getName()} );
			}
		}
	}
	
	$sql = "UPDATE ".$dataset->getSQLTableName()." SET ";
	my $first=1;
	foreach( keys %values ) {
		if( $first )
		{
			$first = 0;
		}
		else
		{
			$sql.= ", ";
		}
		$sql.= "$_ = \"".prep_value($values{$_})."\"";
	}
	$sql.=" WHERE $where";
	
	$rv = $rv && $self->do( $sql );

	# Erase old, and insert new, values into aux-tables.
	my $multifield;
	foreach $multifield ( @aux )
	{
		my $auxtable = $dataset->getSQLSubTableName( $multifield );
		$sql = "DELETE FROM $auxtable WHERE $where";
		$rv = $rv && $self->do( $sql );

		# skip to next table if there are no values at all for this
		# one.
		if( !defined $data->{$multifield->getName()} )
		{
			next;
		}
print STDERR "*".$data->{$multifield->getName()}."\n";
print STDERR "*".$multifield->getName()."\n";
		my $i=0;
		foreach( @{$data->{$multifield->getName()}} )
		{
			$sql = "INSERT INTO $auxtable (".$keyfield->getName().",pos,";
			if( $multifield->isType( "name ") )
			{
				$sql.=$multifield->getName()."_given, ";
				$sql.=$multifield->getName()."_family";
			}
			else
			{
				$sql.=$multifield->getName();
			}
			$sql .= ") VALUES (\"$keyvalue\",\"$i\",";
			if( $multifield->isType( "name ") )
			{
				$sql .= "\"".prep_value($_->{given})."\",";
				$sql .= "\"".prep_value($_->{family})."\"";
			}
			else
			{
				$sql .= "\"".prep_value($_)."\"";
			}
			$sql.=")";
	                $rv = $rv && $self->do( $sql );

			if( $multifield->isTextIndexable() )
			{
				$self->_freetext_index( $dataset, $keyvalue, $multifield, $_ );
			}

			++$i;
		}
	}
	
	# Return with an error if unsuccessful
	return( defined $rv );
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
die "remove not fini_cjgshed";# don't forget to prep values
	my( $self, $tableid, $field, $value ) = @_;

	my $table = table_name( $tableid );
	
	my $sql = "DELETE FROM $table WHERE $field LIKE \"$value\";";

	my $rv = $self->do( $sql );

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
	my $sql = "CREATE TABLE ".EPrints::Database::table_name( $TID_COUNTER ).
		"(countername VARCHAR(255) PRIMARY KEY, counter INT NOT NULL);";
	
	# Send to the database
	my $sth = $self->do( $sql );
	
	# Return with an error if unsuccessful
	return( 0 ) unless defined( $sth );

	# Create the counters
	foreach (@EPrints::Database::counters)
	{
		$sql = "INSERT INTO ".EPrints::Database::table_name( $TID_COUNTER)." VALUES ".
			"(\"$_\", 0);";

		$sth = $self->do( $sql );
		
		# Return with an error if unsuccessful
		return( 0 ) unless defined( $sth );
	}
	
	# Everything OK
	return( 1 );
}

######################################################################
#
# $success = _create_tempmap_table()
#
#  Creates the temporary table map table.
#
######################################################################

sub _create_tempmap_table
{
	my( $self ) = @_;
	
	# The table creation SQL
	my $sql = "CREATE TABLE ".EPrints::Database::table_name( $TID_TEMPMAP ).
		"(tableid INTEGER NOT NULL PRIMARY KEY AUTO_INCREMENT, ".
		"created DATETIME NOT NULL)";
	
	# Send to the database
	my $sth = $self->do( $sql );
	
	# Return with an error if unsuccessful
	return( 0 ) unless defined( $sth );

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
	# still not appy with this #cjg (prep values too?)
	my( $self, $counter ) = @_;

	# Update the counter	
	my $sql = "UPDATE ".EPrints::Database::table_name( $TID_COUNTER )." SET counter=".
		"LAST_INSERT_ID(counter+1) WHERE countername LIKE \"$counter\";";
	
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
#
# $cacheid = create_cache( $keyname )
#
######################################################################

sub create_cache
{
	my ( $self , $keyname ) = @_;

	my $sql;

	$sql = "INSERT INTO ".EPrints::Database::table_name( $TID_TEMPMAP ).
	       "VALUES ( NULL , NOW() )";
	
	$self->do( $sql );

	$sql = "SELECT LAST_INSERT_ID()";

#EPrints::Log::debug( "Database", "SQL:$sql" );

	my $sth = $self->prepare( $sql );
	$self->execute( $sth, $sql );
	my ( $id ) = $sth->fetchrow_array;

	my $tmptable  = "cache".$id;

        $sql = "CREATE TABLE $tmptable ".
	       "( $keyname VARCHAR(255) NOT NULL)";

	$self->do( $sql );
	
	return $tmptable;
}



sub create_buffer
{
	my ( $self , $keyname ) = @_;

#EPrints::Log::debug( "Database", "SQL:$sql" );

	my $tmptable = "searchbuffer".($NEXTBUFFER++);

        my $sql = "CREATE TEMPORARY TABLE $tmptable ".
	          "( $keyname VARCHAR(255) NOT NULL, INDEX($keyname))";

	$self->do( $sql );
	
	return $tmptable;
}


######################################################################
#
# $buffer = buffer( $table, $auxtables{}, $conditions)
#
#  perform a search and store the keys of the results in
#  a buffer tmp table.
#
######################################################################

sub _make_select
{
	my( $self, $keyfield, $tables, $conditions ) = @_;
	
	my $sql= "SELECT ".((keys %{$tables})[0]).".$keyfield->{name} FROM ";
	my $first = 1;
	foreach( keys %{$tables} )
	{
		$sql .= " INNER JOIN " unless( $first );
		$sql .= "${$tables}{$_} AS $_";
		$sql .= " USING ($keyfield->{name})" unless( $first );
		$first = 0;
	}
	if( defined $conditions )
	{
		$sql .= " WHERE $conditions";
	}


	return $sql;
}

sub buffer
{
	my( $self, $keyfield, $tables, $conditions , $orbuffer , $keep ) = @_;

	# can we be REALLY lazy here?
	if( !defined $orbuffer && !$keep && !defined $conditions && scalar(keys %{$tables})==1 ) {
		# We're just going to copy from one table into a brand new one.
		# Might as well just return the ID of the previous table.
		
		return (values %{$tables})[0];
		
	}

	my $sql = $self->_make_select( $keyfield, $tables, $conditions );

	my $targetbuffer;

	if( defined $orbuffer )
	{
		$targetbuffer = $orbuffer;
	} 
	elsif( $keep )
	{
		$targetbuffer = $self->create_cache( $keyfield->{name} );
	}
	else
	{
		$targetbuffer = $self->create_buffer( $keyfield->{name} );
	}

	$self->do( "INSERT INTO $targetbuffer $sql" );

	return( $targetbuffer );
}

sub distinct_and_limit
{
	my( $self, $buffer, $keyfield, $max ) = @_;
	my $tmptable = $self->create_buffer( $keyfield->{name} );
	my $sql = "INSERT INTO $tmptable SELECT DISTINCT $keyfield->{name} FROM $buffer";
	if( defined $max )
	{
		$sql.= " LIMIT $max";
	}
	$self->do( $sql );
	if( defined $max )
	{
		my $count = $self->count_buffer( $tmptable );
		return( $tmptable , ($count >= $max) );
	}
	else
	{
		return( $tmptable , 0 );
	}
}

sub drop_cache
{
	my ( $self , $tmptable ) = @_;
	# sanity check! Dropping the wrong table could be
	# VERY bad.	
	if ( $tmptable =~ m/^cache(\d+)$/ )
	{
		my $sql;

		$sql = "DELETE FROM ".EPrints::Database::table_name( $TID_TEMPMAP ).
	               "WHERE tableid = $1";

		$self->do( $sql );

        	$sql = "DROP TABLE $tmptable";

		$self->do( $sql );
		
	}
	else
	{
		EPrints::Log::log_entry( 
			"L:bad_cache",
			{ tableid=>$tmptable } );
	}

}

sub count_buffer
{
	my ( $self , $buffer ) = @_;

	my $sql = "SELECT COUNT(*) FROM $buffer";

#EPrints::Log::debug( "Database", "SQL:$sql" );

	my $sth = $self->prepare( $sql );
	$self->execute( $sth, $sql );
	my ( $count ) = $sth->fetchrow_array;

	return $count;
}

sub from_buffer 
{
	my ( $self , $tableid , $buffer ) = @_;
	return $self->_get( $tableid, 1 , $buffer );
}

sub get_single
{
	my ( $self , $tableid , $value ) = @_;
	return ($self->_get( $tableid, 0 , $value ))[0];
}

sub get_all
{
	my ( $self , $tableid ) = @_;
	return $self->_get( $tableid, 2 );
}

sub _get 
{
	my ( $self , $dataset , $mode , $param ) = @_;

	# mode 0 = one or none entries from a given primary key
	# mode 1 = many entries from a buffer table
	# mode 2 = return the whole table (careful now)

	my $table = $dataset->getSQLTableName();

	my @fields = $dataset->getFields();

	my $keyfield = $fields[0];

	my $cols = "";
	my @aux = ();
	my $first = 1;
	foreach (@fields) {
		if ( $_->{multiple}) 
		{ 
			push @aux,$_;
		}
		else 
		{
			if ($first)
			{
				$first = 0;
			}
			else
			{
				$cols .= ", ";
			}
			my $col = "M.".$_->{name};
			if ( $_->{type} == $FT_NAME )
			{
				$col = "M.$_->{name}_given,M.$_->{name}_family";
			}
			$cols .= $col;
		}
	}
	my $sql;
	if ( $mode == 0 )
	{
		$sql = "SELECT $cols FROM $table AS M WHERE M.$keyfield->{name} = \"".prep_value($param)."\"";
	}
	elsif ( $mode == 1 )	
	{
		$sql = "SELECT $cols FROM $param AS C, $table AS M WHERE M.$keyfield->{name} = C.$keyfield->{name}";
	}
	elsif ( $mode == 2 )	
	{
		$sql = "SELECT $cols FROM $table AS M";
	}
	my $sth = $self->prepare( $sql );
	$self->execute( $sth, $sql );
	my @data = ();
	my @row;
	my %lookup = ();
	my $count = 0;
	while( @row = $sth->fetchrow_array ) 
	{
		my $record = {};
		$lookup{$row[0]} = $count;
		foreach( @fields ) { 
			if ( $_->{multiple} )
			{
				$$record{$_->{name}} = [];
			}
			else 
			{
				my $value;
				if ($_->get_type() eq "name" )
				{
					$value = {};
					$value->{given} = shift @row;
					$value->{family} = shift @row;
				} 
				else
				{
					$value = shift @row;
				}
				$$record{$_->{name}} = $value;
			}
		}
		$data[$count] = $record;
		$count++;
	}

	my $multifield;
	foreach $multifield ( @aux )
	{
		my $col = "M.$multifield->{name}";
		if ( $multifield->get_type() eq "name" )
		{
			$col = "M.$multifield->{name}_given,M.$multifield->{name}_family";
		}
		
		$col =~ s/\$\(name\)/M.$multifield->{name}/g;
		if ( $mode == 0 )	
		{
			$sql = "SELECT M.$keyfield->{name},M.pos,$col FROM ";
			$sql.= $dataset->getSQLSubTableName( $multifield )." AS M ";
			$sql.= "WHERE M.$keyfield->{name}=\"".prep_value( $param )."\"";
		}
		elsif ( $mode == 1)
		{
			$sql = "SELECT M.$keyfield->{name},M.pos,$col FROM ";
			$sql.= "$param AS C, ";
			$sql.= $dataset->getSQLSubTableName( $multifield )." AS M ";
			$sql.= "WHERE M.$keyfield->{name}=C.$keyfield->{name}";
		}	
		elsif ( $mode == 2)
		{
			$sql = "SELECT M.$keyfield->{name},M.pos,$col FROM ";
			$sql.= $dataset->getSQLSubTableName( $multifield )." AS M ";
		}
		$sth = $self->prepare( $sql );
		$self->execute( $sth, $sql );
		my ( $id , $pos , @values);
		while( ($id , $pos , @values) = $sth->fetchrow_array ) 
		{
			my $n = $lookup{ $id };
			my $value;
			if ( $multifield->get_type() eq "name" )
			{
				$value = {};
				$value->{given} = shift @values;
				$value->{family} = shift @values;
			} 
			else
			{
				$value = shift @values;
			}
			$data[$n]->{$multifield->{name}}->[$pos] = $value;
		}
	}	

	foreach( @data )
	{
		$_ = $dataset->make_object( $self->{session} ,  $_);
	}

	return @data;
}

sub do 
{
	my ( $self , $sql ) = @_;

	my $result = $self->{dbh}->do( $sql );

	if ( !$result ) {
		print "--------\n";
		print "DBErr:\n";
		print "$sql\n";
		print "----------\n";
	}
EPrints::Log::debug( "   ".$sql );

	return $result;
}

sub prepare 
{
	my ( $self , $sql ) = @_;

	my $result = $self->{dbh}->prepare( $sql );

	if ( !$result ) {
		print "--------\n";
		print "DBErr:\n";
		print "$sql\n";
		print "----------\n";
	}
#EPrints::Log::debug( "   ".$sql );

	return $result;
}

sub execute 
{
	my ( $self , $sth , $sql ) = @_;

	my $result = $sth->execute();

	if ( !$result ) {
		print "--------\n";
		print "DBErr:\n";
		print "$sql\n";
		print "----------\n";
	}
EPrints::Log::debug( "   ".$sql );

	return $result;
}

sub benchmark
{
	my ( $self , $keyfield , $tables , $where ) = @_;

	my $sql = $self->_make_select( $keyfield, $tables, $where );

	$sql= "EXPLAIN $sql";

	my $sth = $self->prepare( $sql );
	$self->execute( $sth , $sql );
	my @info = $sth->fetchrow_array;

	return $info[6];

}	

sub exists
{
	my( $self, $tableid, $id ) = @_;

	if( !defined $id )
	{
		return undef;
	}
	my $table = table_name( $tableid );
	
	my @fields = $self->{session}->{metainfo}->get_fields( $tableid );
	my $keyfield = $fields[0]->{name};

	my $sql = "SELECT $keyfield FROM $table WHERE $keyfield = \"".prep_value( $id )."\";";

	my $sth = $self->prepare( $sql );
	$self->execute( $sth , $sql );

	if( $sth->fetchrow_array )
	{ 
		return 1;
	}
	return 0;
}

sub _freetext_index
{
	my( $self , $dataset , $id , $field , $value ) = @_;
				# nb. id is already escaped

	my $rv = 1;
	if( !defined $value || $value eq "" )
	{
		return $rv;
	}

	my $keyfield = $dataset->getKeyField();

	my $indextable = $dataset->getSQLIndexTableName();
	
	my( $good , $bad ) = $self->{session}->getSite()->call( "extract_words" , $value );

	my $sql;
	foreach( @{$good} )
	{
		$sql = "INSERT INTO $indextable ( ".$keyfield->getName()." , fieldword ) VALUES ";
		$sql.= "( \"$id\" , \"".prep_value($field->getName().":$_")."\")";
		$rv = $rv && $self->do( $sql );
	} 
	return $rv;
}


sub table_name
{
	my( $tableid ) = @_;
die "kill me".join(",",caller());
	return $TABLE_NAMES{ $tableid };
}


1; # For use/require success
