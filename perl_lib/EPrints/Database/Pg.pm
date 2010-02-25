######################################################################
#
# EPrints::Database::Pg
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

=for Pod2Wiki

=head1 NAME

B<EPrints::Database::Pg> - custom database methods for PostgreSQL DB

=head1 DESCRIPTION

=head2 TODO

=over 4

=item epadmin create

=item $name = $db->index_name( $table, @columns )

=back

=head1 METHODS

=cut

package EPrints::Database::Pg;

use EPrints::Database qw( :sql_types );

@ISA = qw( EPrints::Database );

use strict;

sub connect
{
	my( $self ) = @_;

	# Connect to the database
	$self->{dbh} = DBI->connect( EPrints::Database::build_connection_string( 
			dbdriver => $self->{session}->get_repository->get_conf("dbdriver"),
			dbhost => $self->{session}->get_repository->get_conf("dbhost"),
			dbsock => $self->{session}->get_repository->get_conf("dbsock"),
			dbport => $self->{session}->get_repository->get_conf("dbport"),
			dbname => $self->{session}->get_repository->get_conf("dbname"), ),
	        $self->{session}->get_repository->get_conf("dbuser"),
	        $self->{session}->get_repository->get_conf("dbpass"),
			{ AutoCommit => 1 } );

	return unless defined $self->{dbh};	

	$self->{dbh}->{pg_enable_utf8} = 1;

	if( $self->{session}->{noise} >= 4 )
	{
		$self->{dbh}->trace( 2 );
	}

	return 1;
}

sub type_info
{
	my( $self, $data_type ) = @_;

	if( $data_type eq SQL_BIGINT )
	{
		return {
			TYPE_NAME => "bigint",
			CREATE_PARAMS => "",
		};
	}
	elsif( $data_type eq SQL_TINYINT )
	{
		return {
			TYPE_NAME => "smallint",
			CREATE_PARAMS => "",
		};
	}
	elsif( $data_type eq SQL_LONGVARCHAR )
	{
		return {
			TYPE_NAME => "text",
			CREATE_PARAMS => "",
		};
	}
	elsif( $data_type eq SQL_LONGVARBINARY )
	{
		return {
			TYPE_NAME => "bytea",
			CREATE_PARAMS => "",
		};
	}
	else
	{
		return $self->{dbh}->type_info( $data_type );
	}
}

sub create
{
	my( $self, $username, $password ) = @_;

	my $repo = $self->{session}->get_repository;

	my $dbh = DBI->connect( EPrints::Database::build_connection_string( 
			dbdriver => "Pg",
			dbhost => $repo->get_conf("dbhost"),
			dbsock => $repo->get_conf("dbsock"),
			dbport => $repo->get_conf("dbport"),
			dbname => "postgres", ),
	        $username,
	        $password,
			{ AutoCommit => 1 } );

	return undef if !defined $dbh;

	my $dbuser = $repo->get_conf( "dbuser" );
	my $dbpass = $repo->get_conf( "dbpass" );
	my $dbname = $repo->get_conf( "dbname" );

	my $rc = 1;
	
	my( $has_dbuser ) = $dbh->selectrow_array("SELECT 1 FROM pg_user WHERE usename=?", {}, $dbuser);

	if( $has_dbuser )
	{
		$repo->log( "Warning! Database already has a user account '$dbuser'" );
	}
	else
	{
		$rc &&= $dbh->do( "CREATE USER ".$dbh->quote_identifier($dbuser)." PASSWORD ?", {}, $dbpass );
	}
	$rc &&= $dbh->do( "CREATE DATABASE ".$dbh->quote_identifier($dbname)." WITH OWNER ".$dbh->quote_identifier($dbuser)." ENCODING ?", {}, "UNICODE" );

	$dbh->disconnect;

	$self->connect();

	return 0 if !defined $self->{dbh};

	return $rc;
}

sub get_column_type
{
	my( $self, $name, $data_type, $not_null, $length, $scale, %opts ) = @_;

	my $type = $self->SUPER::get_column_type( @_[1..$#_] );

	# character coding is DB level in PostgreSQL
	$type =~ s/ COLLATE \S+//;
	$type =~ s/ CHARACTER SET \S+//;

	return $type;
}

sub _create_table
{
	my( $self, $table, $primary_key, $columns ) = @_;

	# PostgreSQL driver always prints a warning on PRIMARY KEY
	local $SIG{__WARN__} = sub { print STDERR @_ if $_[0] !~ m/NOTICE:  CREATE TABLE/; };

	return $self->SUPER::_create_table( @_[1..$#_] );
}

# column_info() under DBD::Pg returns reserved identifiers in quotes, so
# instead we'll query the information_schema
sub has_table
{
	my( $self, $table ) = @_;

	my( $rc ) = $self->{dbh}->selectrow_array( "SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name=?", {}, $table );

	return $rc;
}

sub has_column
{
	my( $self, $table, $column ) = @_;

	my( $rc ) = $self->{dbh}->selectrow_array( "SELECT 1 FROM information_schema.columns WHERE table_name=? AND column_name=?", {}, $table, $column );

	return $rc;
}

sub has_sequence
{
	my( $self, $name ) = @_;

	my( $rc ) = $self->{dbh}->selectrow_array( "SELECT 1 FROM pg_class WHERE relkind='S' AND relname=?", {}, $name );

	return $rc;
}

sub get_tables
{
	my( $self ) = @_;

	my $tables = $self->{dbh}->selectall_arrayref( "SELECT table_name FROM information_schema.tables WHERE table_schema='public'" );

	return map { @$_ } @$tables;
}

sub counter_current
{
	my( $self, $counter ) = @_;

	$counter .= "_seq";

	my( $id ) = $self->{dbh}->selectrow_array("SELECT currval(?)", {}, $counter);

	return $id + 0;
}

sub counter_next
{
	my( $self, $counter ) = @_;

	$counter .= "_seq";

	my( $id ) = $self->{dbh}->selectrow_array("SELECT nextval(?)", {}, $counter);

	return $id + 0;
}

# PostgreSQL's bytea quoting
sub quote_binary
{
	my( $self, $bytes ) = @_;

	$bytes =~ s/\\/\\\\/g;
	$bytes =~ s/\0/\\000/g;

	return $bytes;
}

sub prepare_regexp
{
	my( $self, $col, $value ) = @_;

	return "$col ~* $value";
}

sub _cache_from_SELECT
{
	my( $self, $cachemap, $dataset, $select_sql ) = @_;

	my $cache_table  = $cachemap->get_sql_table_name;
	my $cache_seq = $cache_table . "_seq";
	my $Q_pos = $self->quote_identifier( "pos" );
	my $key_field = $dataset->get_key_field();
	my $Q_keyname = $self->quote_identifier($key_field->get_sql_name);

	$self->create_sequence( $cache_seq );

	my $sql = "";
	$sql .= "INSERT INTO ".$self->quote_identifier( $cache_table );
	$sql .= "($Q_pos, $Q_keyname)";
	$sql .= " SELECT nextval(".$self->quote_value( $cache_seq )."), $Q_keyname";
	$sql .= " FROM ($select_sql) ".$self->quote_identifier( "S" );

	$self->do( $sql );

	$self->drop_sequence( $cache_seq );
}

# unsupported
sub index_name
{
	my( $self, $table, @cols ) = @_;

	return 1;
}

1;
