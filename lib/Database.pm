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
use EPrints::EPrint;
use EPrints::Subscription;

my $DEBUG_SQL = 0;

# cjg not using transactions so there is a (very small) chance of
# dupping on a counter. 

#
# Counters
#
@EPrints::Database::counters = ( "eprintid","userid" );


#
#
# ID of next buffer table. This can safely reset to zero each time
# The module restarts as it is only used for temporary tables.
#
my $NEXTBUFFER = 0;
my %TEMPTABLES = ();
######################################################################
#
# connection_handle build_connection_string( %params )
#                                            
#  Build the string to use to connect via DBI
#  params are:
#     dbhost, dbport, dbname and dbsock.
#  Only dbname is required.
#
######################################################################

sub build_connection_string
{
	my( %params ) = @_;

        # build the connection string
        my $dsn = "DBI:mysql:database=$params{dbname}";
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
#
# EPrints::Database new( $session )
#                        EPrints::Session
#                          
#  Connect to the database.
#
######################################################################

## WP1: BAD
sub new
{
	my( $class , $session) = @_;

	my $self = {};
	bless $self, $class;
	$self->{session} = $session;

	# Connect to the database
	$self->{dbh} = DBI->connect( 
		build_connection_string( 
			dbhost => $session->get_archive()->get_conf("dbhost"),
			dbsock => $session->get_archive()->get_conf("dbsock"),
			dbport => $session->get_archive()->get_conf("dbport"),
			dbname => $session->get_archive()->get_conf("dbname") ),
	        $session->get_archive()->get_conf("dbuser"),
	        $session->get_archive()->get_conf("dbpass") );

#	        { PrintError => 0, AutoCommit => 1 } );

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

## WP1: BAD
sub disconnect
{
	my( $self ) = @_;
	# Make sure that we don't disconnect twice, or inappropriately
	if( defined $self->{dbh} )
	{
		$self->{dbh}->disconnect() ||
			$self->{session}->get_archive()->log( "Database disconnect error: ".
				$self->{dbh}->errstr );
	}
}


######################################################################
#
# $error = error()
# string 
# 
#  Gives details of any errors that have occurred
#
######################################################################

## WP1: BAD
sub error
{
	my( $self ) = @_;
	
	return $self->{dbh}->errstr;
}


######################################################################
#
# $success = create_archive_tables()
# boolean 
#
#  Creates the archive tables (user, archive and buffer) from the
#  metadata tables.
#
######################################################################

## WP1: BAD
sub create_archive_tables
{
	my( $self ) = @_;
	
	my $success = 1;

	foreach( "user" , "inbox" , "buffer" , "archive" ,
		 "document" , "subject" , "subscription" , "deletion" )
	{
		$success = $success && $self->_create_table( 
			$self->{session}->get_archive()->get_dataset( $_ ) );
	}

	$success = $success && $self->_create_tempmap_table();

	$success = $success && $self->_create_counter_table();
	
	return( $success );
}
		


######################################################################
#
# $success = _create_table( $dataset )
# boolean                   EPrints::DataSet
#
#  Create a database table to contain the given dataset.
#
#  The aux. function has an extra parameter which means the table
#  has no primary key, this is for purposes of recursive table 
#  creation (aux. tables have no primary key)
#
######################################################################

## WP1: BAD
sub _create_table
{
	my( $self, $dataset ) = @_;
	
	my $rv = 1;

	my $keyfield = $dataset->get_key_field()->clone;

	my $fieldpos = EPrints::MetaField->new( 
		name => "pos", 
		type => "int" );
	my $fieldword = EPrints::MetaField->new( 
		name => "fieldword", 
		type => "text");
	my $fieldids = EPrints::MetaField->new( 
		name => "ids", 
		type => "longtext");

	# Create the index tables
	$rv = $rv & $self->_create_table_aux(
			$dataset->get_sql_index_table_name,
			$dataset,
			0, # no primary key
			( $fieldword, $fieldpos, $fieldids ) );
	$rv = $rv & $self->_create_table_aux(
			$dataset->get_sql_rindex_table_name,
			$dataset,
			0, # no primary key
			( $keyfield, $fieldword ) );
	return 0 unless $rv;

	# Create sort values table. These will be used when ordering search
	# results.
	my @fields = $dataset->get_fields( 1 );
	# remove the key field
	splice( @fields, 0, 1 ); 
	my @orderfields = ( $keyfield );
	my $langid;
	foreach $langid ( @{$self->{session}->get_archive()->get_conf( "languages" )} )
	{
		foreach( @fields )
		{
			my $fname = $_->get_sql_name()."_".$langid;
			push @orderfields, EPrints::MetaField->new( 
						name => $fname,
						type => "longtext" );
		}
	}
	$rv = $rv && $self->_create_table_aux( 
				$dataset->get_ordervalues_table_name(), 
				$dataset, 
				1, 
				@orderfields );
	return 0 unless $rv;


	# Create the other tables
	$rv = $rv && $self->_create_table_aux( 
				$dataset->get_sql_table_name, 
				$dataset, 
				1, 
				$dataset->get_fields( 1 ) );

	return $rv;
}

# $rv = _create_table_aux( $tablename, $dataset, $setkey, @fields )
# boolean                  string      |         boolean  array of
#                                      EPrints::DataSet   EPrint::MetaField

## WP1: BAD
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

	# Iterate through the fields
	foreach $field (@fields)
	{
		if ( $field->get_property( "multiple" ) ||
		     $field->get_property( "multilang" ) )
		{ 	
			# make an aux. table for a multiple field
			# which will contain the same type as the
			# key of this table paired with the non-
			# multiple version of this field.
			# auxfield and keyfield must be indexed or 
			# there's not much point. 

			my $auxfield = $field->clone;
			$auxfield->set_property( "multiple", 0 );
			$auxfield->set_property( "multilang", 0 );
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
					name => "pos", 
					type => "int" );
				push @auxfields,$pos;
			}
			if ( $field->get_property( "multilang" ) )
			{
				my $lang = EPrints::MetaField->new( 
					name => "lang", 
					type => "langid" );
				push @auxfields,$lang;
			}
			push @auxfields,$auxfield;
			my $rv = $rv && $self->_create_table_aux(	
				$dataset->get_sql_sub_table_name( $field ),
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
		my $notnull = 0;
			
		# First field is primary key.
		if( !defined $key && $setkey)
		{
			$key = $field;
			$notnull = 1;
		}
		else
		{
			my( $index ) = $field->get_sql_index();
			if( defined $index )
			{
				push @indices, $index;
			}
		}
		$sql .= $field->get_sql_type( $notnull );

	}
	if ( $setkey )	
	{
		$sql .= ", PRIMARY KEY (".$key->get_sql_name().")";
	}

	
	foreach (@indices)
	{
		$sql .= ", $_";
	}
	
	$sql .= ");";
	

	# Send to the database
	$rv = $rv && $self->do( $sql );
	
	# Return with an error if unsuccessful
	return( defined $rv );
}


######################################################################
#
# $success = add_record( $dataset, $data )
# boolean                |         Structured Data
#                        EPrints::DataSet     
#
#  Add data to the given table. 
#
######################################################################

## WP1: BAD
sub add_record
{
	my( $self, $dataset, $data ) = @_;

 #print STDERR "-----------------ADD RECORD------------------\n";
	my $table = $dataset->get_sql_table_name();
	
	my $keyfield = $dataset->get_key_field();

	# To save duplication of code, all this function does is insert
	# a stub entry, then call the update method which does the hard
	# work.

	my $sql = "INSERT INTO ".$dataset->get_sql_table_name()." ";
	$sql   .= " (".$dataset->get_key_field()->get_sql_name().") ";
	$sql   .= "VALUES (\"".
	          prep_value( $data->{$dataset->get_key_field()->get_sql_name()} )."\")";

	# Send to the database
	my $rv = $self->do( $sql );

	# Now add the ACTUAL data:
	$self->update( $dataset , $data );
	
	# Return with an error if unsuccessful
	return( defined $rv );
}


######################################################################
#
# $munged = prep_value( $value )
#
# [STATIC]
#  Modify value such that " becomes \" and \ becomes \\ 
#  Returns "" if $value is undefined.
#
######################################################################

## WP1: BAD
sub prep_value
{
	my( $value ) = @_; 
	
	if( !defined $value )
	{
		return "";
	}
	
	$value =~ s/["\\.'%]/\\$&/g;
	return $value;
}


## WP1: BAD
sub update
{
	my( $self, $dataset, $data ) = @_;
	#my( $database_self, $dataset_ds, $struct_md_data ) = @_;

#use Data::Dumper;
#print STDERR "-----------------UPDATE RECORD------------------\n";
#print STDERR Dumper($data);
#print STDERR "-----------------////UPDATE RECORD ------------------\n";

	my $rv = 1;
	my $sql;

	my @fields = $dataset->get_fields( 1 );

	my $keyfield = $dataset->get_key_field();

	my $keyvalue = prep_value( $data->{$keyfield->get_sql_name()} );

	# The same WHERE clause will be used a few times, so lets define
	# it now:
	my $where = $keyfield->get_sql_name()." = \"$keyvalue\"";

	$self->_deindex( $dataset, $keyvalue );

	my @aux;
	my %values = ();
	my $field;
	foreach $field ( @fields ) 
	{
		if( $field->is_type( "secret" ) &&
			!EPrints::Utils::is_set( $data->{$field->get_name()} ) )
		{
			# No way to blank a secret field, as a null value
			# is totally skipped when updating.
			next;
		}
		if( $field->get_property( "multiple" ) || $field->get_property( "multilang" ) ) 
		{ 
			push @aux,$field;
		}
		else 
		{
			my $value = $field->which_bit( $data->{$field->get_name()} );
			my $colname = $field->get_sql_name();
			if( $field->get_property( "idpart" ) )
			{
				$value = $value->{id};
			}
			if( $field->get_property( "mainpart" ) )
			{
				$value = $value->{main};
			}
			# clearout the freetext search index table for this field.

			if( $field->is_type( "name" ) )
			{
				$values{$colname."_honourific"} = $value->{honourific};
				$values{$colname."_given"} = $value->{given};
				$values{$colname."_family"} = $value->{family};
				$values{$colname."_lineage"} = $value->{lineage};
			}
			else
			{
				$values{$colname} = $value;
			}
			if( $field->is_text_indexable )
			{ 
				$self->_freetext_index( 
					$dataset, 
					$keyvalue, 
					$field, 
					$value );
			}
		}
	}
	
	$sql = "UPDATE ".$dataset->get_sql_table_name()." SET ";
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
		$sql.= "$_ = ";
		if( defined $values{$_} ) 
		{
			$sql.= "\"".prep_value( $values{$_} )."\"";
		}
		else
		{
			$sql .= "NULL";
		}
	}
	$sql.=" WHERE $where";
	
	$rv = $rv && $self->do( $sql );

	# Erase old, and insert new, values into aux-tables.
	my $multifield;
	foreach $multifield ( @aux )
	{
		my $auxtable = $dataset->get_sql_sub_table_name( $multifield );
		$sql = "DELETE FROM $auxtable WHERE $where";
		$rv = $rv && $self->do( $sql );

		# skip to next table if there are no values at all for this
		# one.
		if( !EPrints::Utils::is_set( $data->{$multifield->get_name()} ) )
		{
			next;
		}
		my @values;
		my $fieldvalue = $data->{$multifield->get_name()};

		if( $multifield->get_property( "multiple" ) )
		{
			my $position=0;
			my $pos;
			foreach $pos (0..(scalar @{$fieldvalue}-1) )
			{
				my $value = $multifield->which_bit( $fieldvalue->[$pos] );
				my $incp = 0;
				if( $multifield->get_property( "multilang" ) )
				{
					my $langid;
					foreach $langid ( keys %{$value} )
					{
						my $val = $value->{$langid};
						if( defined $val )
						{
							push @values, {
								v => $val,
								p => $position,
								l => $langid
							};
							$incp=1;
						}
					}
				}
				else
				{
					if( defined $value )
					{
						push @values, {
							v => $value,
							p => $position
						};
						$incp=1;
					}
				}
				$position++ if $incp;
				#print STDERR "xxxx($incp)\n";
			}
		}
		else
		{
			my $value = $multifield->which_bit( $fieldvalue );
#print STDERR "ML".$multifield->get_name()." ".Dumper($value,$value)."\n-----------\n";
			if( $multifield->get_property( "multilang" ) )
			{
#print STDERR "1 ".$multifield->get_name()." ".Dumper($value)."\n";
				my $langid;
				foreach $langid ( keys %{$value} )
				{
					my $val = $value->{$langid};
#print STDERR "2 ".$multifield->get_name()." $langid=> ".Dumper($val)."\n";
					if( defined $val )
					{
						push @values, { 
							v => $val,
							l => $langid
						};
					}
				}
			}
			else
			{
				die "This can't happen in update!"; #cjg!
			}
		}
##print STDERR "---(".$multifield->get_name().")---\n";
#use Data::Dumper;
#print STDERR Dumper(@values);
					
		my $v;
		foreach $v ( @values )
		{
			$fname = $multifield->get_sql_name();	
			$sql = "INSERT INTO $auxtable (".$keyfield->get_sql_name().", ";
			$sql.= "pos, " if( $multifield->get_property( "multiple" ) );
			$sql.= "lang, " if( $multifield->get_property( "multilang" ) );
			if( $multifield->is_type( "name" ) )
			{
				$sql .= $fname."_honourific, ";
				$sql .= $fname."_given, ";
				$sql .= $fname."_family, ";
				$sql .= $fname."_lineage ";
			}
			else
			{
				$sql .= $fname;
			}
			$sql .= ") VALUES (\"$keyvalue\", ";
			$sql .=	"\"".$v->{p}."\", " if( $multifield->get_property( "multiple" ) );
			$sql .=	"\"".prep_value( $v->{l} )."\", " if( $multifield->get_property( "multilang" ) );
			if( $multifield->is_type( "name" ) )
			{
				$sql .= "\"".prep_value( $v->{v}->{honourific} )."\", ";
				$sql .= "\"".prep_value( $v->{v}->{given} )."\", ";
				$sql .= "\"".prep_value( $v->{v}->{family} )."\", ";
				$sql .= "\"".prep_value( $v->{v}->{lineage} )."\"";
			}
			else
			{
				$sql .= "\"".prep_value( $v->{v} )."\"";
			}
			$sql.=")";
	                $rv = $rv && $self->do( $sql );


			if( $multifield->is_text_indexable )
			{
				$self->_freetext_index( 
					$dataset, 
					$keyvalue, 
					$multifield, 
					$v->{v} );
			}

			++$position;
		}
	}

	# remove the key field
	splice( @fields, 0, 1 ); 
	my @orderfields = ( $keyfield );
	my $langid;


	my @fnames = ( $keyfield->get_sql_name() );
	my @fvals = ( $keyvalue );
	foreach $langid ( @{$self->{session}->get_archive()->get_conf( "languages" )} )
	{
		foreach( @fields )
		{
			my $ov = $_->ordervalue( 
					$data->{$_->get_name()},
					$self->{session}->get_archive(), 
					$langid );
			
			push @fnames, $_->get_sql_name()."_".$langid;
			push @fvals, prep_value( $ov );
		}
	}

	my $ovt = $dataset->get_ordervalues_table_name();
	$sql = "DELETE FROM ".$ovt." WHERE ".$where;
	$self->do( $sql );

	$sql = "INSERT INTO ".$ovt." (".join( ",", @fnames ).") VALUES (\"".
		join( "\",\"", @fvals )."\")";
	$self->do( $sql );

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
	my( $self, $dataset, $id ) = @_;

	my $rv=1;

	my $keyfield = $dataset->get_key_field();

	my $keyvalue = prep_value( $id );

	my $where = $keyfield->get_sql_name()." = \"$keyvalue\"";


	# Delete from index
	$self->_deindex( $dataset, $id );

	# Delete Subtables
	my @fields = $dataset->get_fields( 1 );
	my $field;
	foreach $field ( @fields ) 
	{
		next unless( $field->get_property( "multiple" ) || $field->get_property( "multilang" ) );
		my $auxtable = $dataset->get_sql_sub_table_name( $field );
		$sql = "DELETE FROM $auxtable WHERE $where";
		$rv = $rv && $self->do( $sql );
	}

	# Delete main table
	$sql = "DELETE FROM ".$dataset->get_sql_table_name()." WHERE ".$where;
	$rv = $rv && $self->do( $sql );

	if( !$rv )
	{
		$self->{session}->get_archive()->log( "Error removing item id: $id" );
	}

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

## WP1: BAD
sub _create_counter_table
{
	my( $self ) = @_;

	my $counter_ds = $self->{session}->get_archive()->get_dataset( "counter" );
	
	# The table creation SQL
	my $sql = "CREATE TABLE ".$counter_ds->get_sql_table_name().
		"(countername VARCHAR(255) PRIMARY KEY, counter INT NOT NULL);";
	
	# Send to the database
	my $sth = $self->do( $sql );
	
	# Return with an error if unsuccessful
	return( 0 ) unless defined( $sth );

	my $counter;
	# Create the counters 
	foreach $counter (@EPrints::Database::counters)
	{
		$sql = "INSERT INTO ".$counter_ds->get_sql_table_name()." VALUES ".
			"(\"$counter\", 0);";

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

## WP1: BAD
sub _create_tempmap_table
{
	my( $self ) = @_;
	
	# The table creation SQL
	my $ds = $self->{session}->get_archive()->get_dataset( "tempmap" );
	my $table_name = $ds->get_sql_table_name();
	my $sql = <<END;
CREATE TABLE $table_name ( 
	tableid INTEGER NOT NULL PRIMARY KEY AUTO_INCREMENT,
	created DATETIME NOT NULL, 
	lastused DATETIME NOT NULL, 
	searchexp TEXT )
END
	
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

## WP1: BAD
sub counter_next
{
	# still not appy with this #cjg (prep values too?)
	my( $self, $counter ) = @_;

	my $ds = $self->{session}->get_archive()->get_dataset( "counter" );

	# Update the counter	
	my $sql = "UPDATE ".$ds->get_sql_table_name()." SET counter=".
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


sub cache_id
{
	my( $self , $code , $include_expired) = @_;

	my $a = $self->{session}->get_archive();
	$ds = $a->get_dataset( "tempmap" );

	#cjg NOT escaped!!!
	my $sql = "SELECT tableid FROM ".$ds->get_sql_table_name() . " WHERE searchexp = '$code'";
	if( !$include_expired )
	{
		# Don't includes expired items
		$sql.= " AND lastused > now()-interval ".$a->get_conf("cache_timeout")." minute"; 
	}
	# Never include items past maxlife
	$sql.= " AND created > now()-interval ".$a->get_conf("cache_maxlife")." hour"; 

	my $sth = $self->prepare( $sql );
	$self->execute( $sth , $sql );

	return $sth->fetchrow_array;
}

sub is_cached
{
	my( $self , $code ) = @_;

	return defined $self->cache_id( $code );
}

sub count_cache
{
	my( $self , $code ) = @_;

	my $id = $self->cache_id( $code , 1 );
	return undef if( !defined $id );

	return $self->count_table( "cache".$id );
}

sub cache
{
	my( $self , $code , $dataset , $srctable , $order ) = @_;

	my $sql;
	my $sth;

	my $ds = $self->{session}->get_archive()->get_dataset( "tempmap" );
	$sql = "INSERT INTO ".$ds->get_sql_table_name()." VALUES ( NULL , NOW(), NOW() , '$code' )";
	
	$self->do( $sql );

	$sql = "SELECT LAST_INSERT_ID()";

	$sth = $self->prepare( $sql );
	$self->execute( $sth, $sql );
	my( $id ) = $sth->fetchrow_array;

	my $keyfield = $dataset->get_key_field();

	my $tmptable  = "cache".$id;

        $sql = "CREATE TABLE $tmptable ".
		"( pos INTEGER NOT NULL PRIMARY KEY AUTO_INCREMENT, ".
		$keyfield->get_sql_type( 1 )." )";
	$self->do( $sql );

	my $keyname = $keyfield->get_name();
	$sql = "INSERT INTO $tmptable SELECT NULL , B.$keyname from ".$srctable." as B";
	if( defined $order )
	{
		$sql .= ", ".$dataset->get_ordervalues_table_name()." AS O";
		$sql .= " WHERE B.$keyname = O.$keyname ORDER BY ";
		my $first = 1;
		foreach( split( "/", $order ) )
		{
			$sql .= ", " if( !$first );
			my $desc = 0;
			if( s/^-// ) { $desc = 1; }
			my $field = EPrints::Utils::field_from_config_string(
					$dataset,
					$_ );
			$sql .= "O.".$field->get_sql_name()."_".$self->{session}->get_langid();
			$sql .= " DESC" if $desc;
			$first = 0;
		}
	}
	$sth = $self->do( $sql );

	return $tmptable;
}



## WP1: BAD
sub create_buffer
{
	my ( $self , $keyname ) = @_;

	my $tmptable = "searchbuffer".($NEXTBUFFER++);
	$TEMPTABLES{$tmptable} = 1;
	#print STDERR "Pushed $tmptable onto temporary table list\n";
#cjg VARCHAR!! Should this not be whatever type is bestest?
        my $sql = "CREATE TEMPORARY TABLE $tmptable ".
	          "( $keyname VARCHAR(255) NOT NULL, INDEX($keyname))";

	$self->do( $sql );
		
	return $tmptable;
}

sub make_buffer
{
	my( $self, $keyname, $data ) = @_;

	my $id = $self->create_buffer( $keyname );

	$sth = $self->prepare( "INSERT INTO $id VALUES (?)" );
	foreach( @{$data} )
	{
		$sth->execute( $_ );
	}

	return $id;
}

# Loop through known temporary tables, and remove them.
sub garbage_collect
{
	my( $self ) = @_;
	#print STDERR "Garbage collect called.\n";
	my $dropped = 0;
	foreach( keys %TEMPTABLES )
	{
		$self->dispose_buffer( $_ );
		$dropped++;
	}

}

sub dispose_buffer
{
	my( $self, $id ) = @_;
	
	return unless( defined $TEMPTABLES{$id} );
	my $sql = "DROP TABLE $id";
	$self->do( $sql );
	delete $TEMPTABLES{$id};

}
	


sub get_index_ids
{
#cjg iffy params
	my( $self, $table, $condition ) = @_;

	print STDERR "GET_INDEX_IDS($table)($condition)\n";
	my $sql = "SELECT M.ids FROM $table as M where $condition";	
	my $results;
	my $sth = $self->prepare( $sql );
	$self->execute( $sth, $sql );
	while( @info = $sth->fetchrow_array ) {
		my @list = split(":",$info[0]);
		# Remove first & last.
		pop @list;
		shift @list;
		push @{$results}, @list;
	}
	return( $results );
}

sub search
{
	my( $self, $keyfield, $tables, $conditions) = @_;
	
	my $sql = "SELECT M.".$keyfield->get_sql_name()." FROM ";
	my $first = 1;
	foreach( keys %{$tables} )
	{
		$sql.= ", " unless($first);
		$first = 0;
		$sql.= $tables->{$_}." AS $_";
	}
	if( defined $conditions )
	{
		$sql .= " WHERE $conditions";
	}

	my $results;
	my $sth = $self->prepare( $sql );
	$self->execute( $sth, $sql );
	while( @info = $sth->fetchrow_array ) {
		push @{$results}, $info[0];
	}
	return( $results );
}



sub drop_cache
{
	my ( $self , $id ) = @_;

	# $id MUST be an integer.
	$id += 0;

	my $tmptable = "cache$id";

	my $sql;
	my $ds = $self->{session}->get_archive()->get_dataset( "tempmap" );
	# We drop the table before removing the entry from the tempmap

       	$sql = "DROP TABLE $tmptable";
	$self->do( $sql );
		
	$sql = "DELETE FROM ".$ds->get_sql_table_name()." WHERE tableid = $id";
	$self->do( $sql );
}

## WP1: BAD
sub count_table
{
	my ( $self , $tablename ) = @_;

	my $sql = "SELECT COUNT(*) FROM $tablename";

	my $sth = $self->prepare( $sql );
	$self->execute( $sth, $sql );
	my ( $count ) = $sth->fetchrow_array;

	return $count;
}

## WP1: BAD
sub from_buffer 
{
	my ( $self , $dataset , $buffer ) = @_;
	return $self->_get( $dataset, 1 , $buffer );
}

sub from_cache
{
	my( $self , $dataset , $code , $offset , $count ) = @_;

	#print STDERR "[$offset][$count]\n";

	# Force offset and count to be ints
	$offset+=0;
	$count+=0;

	my $id = $self->cache_id( $code , 1 );
	my @results = $self->_get( $dataset, 3, "cache".$id, $offset , $count );

	$ds = $self->{session}->get_archive()->get_dataset( "tempmap" );
	my $sql = "UPDATE ".$ds->get_sql_table_name()." SET lastused = NOW() WHERE tableid = $id";
	$self->do( $sql );

	$self->drop_old_caches();

	return @results;
}

sub drop_old_caches
{
	my( $self ) = @_;

	$ds = $self->{session}->get_archive()->get_dataset( "tempmap" );
	my $a = $self->{session}->get_archive();
	my $sql = "SELECT tableid FROM ".$ds->get_sql_table_name()." WHERE";
	$sql.= " lastused < now()-interval ".($a->get_conf("cache_timeout") + 5)." minute"; 
	$sql.= " OR created < now()-interval ".$a->get_conf("cache_maxlife")." hour"; 
	my $sth = $self->prepare( $sql );
	$self->execute( $sth , $sql );
	my $id;
	while( $id  = $sth->fetchrow_array() )
	{
		$self->drop_cache( $id );
	}
}


## WP1: BAD
sub get_single
{
	my ( $self , $dataset , $value ) = @_;
	return ($self->_get( $dataset, 0 , $value ))[0];
}

## WP1: BAD
sub get_all
{
	my ( $self , $dataset ) = @_;
	return $self->_get( $dataset, 2 );
}

## WP1: BAD
sub _get 
{
	my ( $self , $dataset , $mode , $param, $offset, $ntoreturn ) = @_;

# print STDERR "========================================BEGIN _get($mode,$param)\n";
	# mode 0 = one or none entries from a given primary key
	# mode 1 = many entries from a buffer table
	# mode 2 = return the whole table (careful now)
	# mode 3 = some entries from a cache table
use Carp;
if( ref($dataset) eq "" ) { confess(); }

	my $table = $dataset->get_sql_table_name();

	my @fields = $dataset->get_fields( 1 );

	my $field = undef;
	my $keyfield = $fields[0];
	my $kn = $keyfield->get_sql_name();

	my $cols = "";
	my @aux = ();
	my $first = 1;
	foreach $field ( @fields ) {
		if( $field->is_type( "secret" ) )
		{
			# We don't return the values of secret fields - 
			# much more secure that way. The password field is
			# accessed direct via SQL.
			next;
		}
		if( $field->get_property( "multiple" ) || $field->get_property( "multilang" ) )
		{ 
			push @aux,$field;
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
			my $fname = $field->get_sql_name();
			if ( $field->is_type( "name" ) )
			{
				$cols .= "M.".$fname."_honourific, ".
				         "M.".$fname."_given, ".
				         "M.".$fname."_family, ".
				         "M.".$fname."_lineage";
			}
			else 
			{
				$cols .= "M.".$fname;
			}
		}
	}
	my $sql;
	if ( $mode == 0 )
	{
		$sql = "SELECT $cols FROM $table AS M ".
		       "WHERE M.$kn = \"".prep_value( $param )."\"";
	}
	elsif ( $mode == 1 )	
	{
		$sql = "SELECT $cols FROM $param AS C, $table AS M ".
		       "WHERE M.$kn = C.$kn";
	}
	elsif ( $mode == 2 )	
	{
		$sql = "SELECT $cols FROM $table AS M";
	}
	elsif ( $mode == 3 )	
	{
#print STDERR "From cache $param\n";
		$sql = "SELECT $cols, C.pos FROM $param AS C, $table AS M ";
		$sql.= "WHERE M.$kn = C.$kn AND C.pos>$offset ";
		if( $ntoreturn > 0 )
		{
			$sql.="AND C.pos<=".($offset+$ntoreturn)." ";
		}
		$sql .= "ORDER BY C.pos";
		#print STDERR "$sql\n";
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
		foreach $field ( @fields ) { 
			if( $field->is_type( "secret" ) )
			{
				next;
			}
			if( $field->get_property( "multiple" ) )
			{
				#cjg Maybe should do nothing.
				$record->{$field->get_name()} = [];
			}
			elsif( $field->get_property( "multilang" ) )
			{
				# Do Nothing
			}
			else 
			{
				my $value;
				if( $field->is_type( "name" ) )
				{
					$value = {};
					$value->{honourific} = shift @row;
					$value->{given} = shift @row;
					$value->{family} = shift @row;
					$value->{lineage} = shift @row;
				} 
				else
				{
					$value = shift @row;
				}
#print STDERR "FIELD: ".$field->get_sql_name()." ($subbit)\n";
				if( $field->get_property( "mainpart" ) )
				{
#print STDERR "N{$value}\n";
					$record->{$field->get_name()}->{main} = $value;
				}
				elsif( $field->get_property( "idpart" ) )
				{
#print STDERR "O{$value}\n";
					$record->{$field->get_name()}->{id} = $value;
				}
				else
				{
#print STDERR "P{$value}\n";
					$record->{$field->get_name()} = $value;
				}
			}
		}
		$data[$count] = $record;
		$count++;
	}

	foreach( @data )
	{
# use Data::Dumper;
# print STDERR "--------xxxx-----FROM DB------------------\n";
# print STDERR Dumper($_);
# print STDERR "--------xxxx-----////FROM DB------------------\n";
	}

	my $multifield;
	foreach $multifield ( @aux )
	{
		my $mn = $multifield->get_sql_name();
		my $fn = $multifield->get_name();
		my $col = "M.$mn";
		if( $multifield->is_type( "name" ) )
		{
			$col = "M.$mn\_honourific,M.$mn\_given,M.$mn\_family,M.$mn\_lineage";
		}
		my $fields_sql = "M.$kn, ";
		$fields_sql .= "M.pos, " if( $multifield->get_property( "multiple" ) );
		$fields_sql .= "M.lang, " if( $multifield->get_property( "multilang" ) );
		$fields_sql .= $col;		
		if( $mode == 0 )	
		{
			$sql = "SELECT $fields_sql FROM ";
			$sql.= $dataset->get_sql_sub_table_name( $multifield )." AS M ";
			$sql.= "WHERE M.$kn=\"".prep_value( $param )."\"";
		}
		elsif( $mode == 1)
		{
			$sql = "SELECT $fields_sql FROM ";
			$sql.= "$param AS C, ";
			$sql.= $dataset->get_sql_sub_table_name( $multifield )." AS M ";
			$sql.= "WHERE M.$kn=C.$kn";
		}	
		elsif( $mode == 2)
		{
			$sql = "SELECT $fields_sql FROM ";
			$sql.= $dataset->get_sql_sub_table_name( $multifield )." AS M ";
		}
		elsif ( $mode == 3 )	
		{
	print STDERR "From cache $param\n";
			$sql = "SELECT $fields_sql, C.pos FROM $param AS C, "; 
			$sql.= $dataset->get_sql_sub_table_name( $multifield )." AS M ";
			$sql.= "WHERE M.$kn = C.$kn AND C.pos>=$offset ";
			if( $ntoreturn > 0 )
			{
				$sql.="AND C.pos<".($offset+$ntoreturn)." ";
			}
			$sql .= "ORDER BY C.pos";
			print STDERR "$sql\n";
		}
		$sth = $self->prepare( $sql );
		$self->execute( $sth, $sql );
		while( @values = $sth->fetchrow_array ) 
		{
#print STDERR "V:".join(",",@values)."\n";
			my $id = shift( @values );
			my( $pos, $lang );
			$pos = shift( @values ) if( $multifield->get_property( "multiple" ) );
			$lang = shift( @values ) if( $multifield->get_property( "multilang" ) );
			my $n = $lookup{ $id };
#print STDERR "[$n][$id]\n";
			my $value;
			if( $multifield->is_type( "name" ) )
			{
				$value = {};
				$value->{honourific} = shift @values;
				$value->{given} = shift @values;
				$value->{family} = shift @values;
				$value->{lineage} = shift @values;
			} 
			else
			{
				$value = shift @values;
			}
			my $subbit;
			$subbit = "id" if( $multifield->get_property( "idpart" ) );
			$subbit = "main" if( $multifield->get_property( "mainpart" ) );
#print STDERR "MUFIL: ".$multifield->get_sql_name()." ($subbit)\n";

			if( $multifield->get_property( "multiple" ) )
			{
				if( $multifield->get_property( "multilang" ) )
				{
					if( defined $subbit )
					{
						$data[$n]->{$fn}->[$pos]->{$subbit}->{$lang} = $value;
					}
					else
					{
						$data[$n]->{$fn}->[$pos]->{$lang} = $value;
					}
				}
				else
				{
#print STDERR 	"data[".$n."]->{".$fn."}->[".$pos."] = ".$value."\n";
					if( defined $subbit )
					{
						$data[$n]->{$fn}->[$pos]->{$subbit} = $value;
					}
					else
					{
						$data[$n]->{$fn}->[$pos] = $value;
					}
				}
			}
			else
			{
				if( $multifield->get_property( "multilang" ) )
				{
					if( defined $subbit )
					{
						$data[$n]->{$fn}->{$subbit}->{$lang} = $value;
					}
					else
					{

						$data[$n]->{$fn}->{$lang} = $value;
					}
				}
				else
				{
					print STDERR "This cannot happen!\n";#cjg!
				}
			}
		}
	}	

	foreach( @data )
	{
 #use Data::Dumper;
 #print STDERR "-----------------FROM DB------------------\n";
 #print STDERR Dumper($_);
 #print STDERR "-----------------////FROM DB------------------\n";
		$_ = $dataset->make_object( $self->{session} ,  $_);
	}

# print STDERR "========================================END _get\n";
	return @data;
}

sub get_values
{
	my( $self, $field ) = @_;

	my $dataset = $field->get_dataset();

	my $table;
	if ( $field->get_property( "multiple" ) || $field->get_property( "multilang" ) )
	{
		$table = $dataset->get_sql_sub_table_name();
	} 
	else 
	{
		$table = $dataset->get_sql_table_name();
	}
	my $sqlfn = $field->get_sql_name();

	my $sql = "SELECT DISTINCT $sqlfn FROM $table";
	print "($table)($sqlfn)\n";
	$sth = $self->prepare( $sql );
	$self->execute( $sth, $sql );
	my @values = ();
	my $value;
	while( ( $value ) = $sth->fetchrow_array ) 
	{
		push @values, $value;
	}
	return @values;
}


## WP1: BAD
sub do 
{
	my ( $self , $sql ) = @_;

	if( $DEBUG_SQL )
	{
		$self->{session}->get_archive()->log( "Database execute debug: $sql" );
	}
	my $result = $self->{dbh}->do( $sql );

	if ( !$result ) {
		print "<pre>--------\n";
		print "dpDBErr:\n";
		print "$sql\n";
		print "----------</pre>\n";
	}

	return $result;
}

## WP1: BAD
sub prepare 
{
	my ( $self , $sql ) = @_;

	my $result = $self->{dbh}->prepare( $sql );

	if ( !$result ) {
		print "<pre>--------\n";
		print "prepDBErr:\n";
		print "$sql\n";
		print "----------</pre>\n";
	}

	return $result;
}

## WP1: BAD
sub execute 
{
	my ( $self , $sth , $sql ) = @_;

	if( $DEBUG_SQL )
	{
		$self->{session}->get_archive()->log( "Database execute debug: $sql" );
	}
	my $result = $sth->execute;

	if ( !$result ) {
		print "<pre>--------\n";
		print "execDBErr:\n";
		print "$sql\n";
		print "----------</pre>\n";
	}

	return $result;
}


sub exists
{
	my( $self, $dataset, $id ) = @_;

	if( !defined $id )
	{
		return undef;
	}
	
	my $keyfield = $dataset->get_key_field();

	my $sql = "SELECT ".$keyfield->get_sql_name().
		" FROM ".$dataset->get_sql_table_name()." WHERE ".
		$keyfield->get_sql_name()." = \"".prep_value( $id )."\";";

	my $sth = $self->prepare( $sql );
	$self->execute( $sth , $sql );

	if( $sth->fetchrow_array )
	{ 
		return 1;
	}
	return 0;
}

## WP1: BAD
sub _freetext_index
{
	my( $self , $dataset , $id , $field , $value ) = @_;
				# nb. id is already escaped

	my $rv = 1;
	if( !defined $value || $value eq "" )
	{
		return $rv;
	}

	my $keyfield = $dataset->get_key_field();

	my $indextable = $dataset->get_sql_index_table_name();
	my $rindextable = $dataset->get_sql_rindex_table_name();
	
	my( $good , $bad ) = $self->{session}->get_archive()->call( "extract_words" , $value );

	my $sql;
	foreach( @{$good} )
	{
#cjg FOR GODS SAKE make this a transaction...
		my $code = prep_value($field->get_sql_name().":$_");
		my $sth;
		$sql = "SELECT max(pos) FROM $indextable where fieldword='$code'"; 
		$sth=$self->prepare( $sql );
		$rv = $rv && $self->execute( $sth, $sql );
		return 0 unless $rv;
		my ( $n ) = $sth->fetchrow_array;
		my $insert = 0;
		if( !defined $n )
		{
			$n = 0;
			$insert = 1;
		}
		else
		{
			$sql = "SELECT ids FROM $indextable WHERE fieldword='$code' AND pos=$n"; 
			$sth=$self->prepare( $sql );
			$rv = $rv && $self->execute( $sth, $sql );
			my( $ids ) = $sth->fetchrow_array;
			my( @list ) = split( ":",$ids );
			# don't forget the first and last are empty!
			if( (scalar @list)-2 < 128 )
			{
				$sql = "UPDATE $indextable SET ids='$ids$id:' WHERE fieldword='$code' AND pos=$n";	
				$rv = $rv && $self->do( $sql );
				return 0 unless $rv;
			}
			else
			{
				++$n;
				$insert = 1;
			}
		}
		if( $insert )
		{
			$sql = "INSERT INTO $indextable (fieldword,pos,ids ) VALUES ('$code',$n,':$id:')";
			$rv = $rv && $self->do( $sql );
			return 0 unless $rv;
		}
		$sql = "INSERT INTO $rindextable (fieldword,".$keyfield->get_sql_name()." ) VALUES ('$code','$id')";
		$rv = $rv && $self->do( $sql );
		return 0 unless $rv;

	} 
	return $rv;
}



sub _deindex
{
	my( $self, $dataset, $keyvalue ) = @_;

	$rv = 1;

	my $keyfield = $dataset->get_key_field();
	my $where = $keyfield->get_sql_name()." = \"$keyvalue\"";

	# Trim out indexes
	my $indextable = $dataset->get_sql_index_table_name();
	my $rindextable = $dataset->get_sql_rindex_table_name();
	$sql = "SELECT fieldword FROM $rindextable WHERE $where";
	my $sth=$self->prepare( $sql );
	$rv = $rv && $self->execute( $sth, $sql );
	my @codes = ();
	my $code;	
	while( $code = $sth->fetchrow_array )
	{
		push @codes,$code;
	}
	foreach( @codes )
	{
		$code = prep_value( $_ );
		$sql = "SELECT ids,pos FROM $indextable WHERE fieldword='$code' AND ids LIKE '%:$keyvalue:%'";
		$sth=$self->prepare( $sql );
		$rv = $rv && $self->execute( $sth, $sql );
		if( ($ids,$pos) = $sth->fetchrow_array )
		{
			$ids =~ s/:$keyvalue:/:/g;
			$sql = "UPDATE $indextable SET ids = '$ids' WHERE fieldword='$code' AND pos='$pos'";
			$rv = $rv && $self->do( $sql );
		}
	}
	$sql = "DELETE FROM $rindextable WHERE $where";
	$rv = $rv && $self->do( $sql );

	return $rv;
}


1; # For use/require success
