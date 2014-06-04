######################################################################
#
# EPrints::Database::Pg
#
######################################################################
#
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

=head2 PostgreSQL-specific Annoyances

The L<DBD::Pg> SQL_VARCHAR type is mapped to text instead of varchar(n).

=head1 METHODS

=cut

package EPrints::Database::Pg;

use EPrints::Database qw( :sql_types );
use DBD::Pg qw( :pg_types );

@ISA = qw( EPrints::Database );

use strict;

sub connect
{
	my( $self ) = @_;

	my $rc = $self->SUPER::connect;
	return $rc if !$rc;

	$self->{dbh}->{pg_enable_utf8} = 1;

	return $rc;
}

sub type_info
{
	my( $self, $data_type ) = @_;

	if( $data_type eq SQL_TINYINT )
	{
		return {
			TYPE_NAME => "smallint",
			CREATE_PARAMS => "",
			COLUMN_SIZE => 3,
		};
	}
	# DBD::Pg maps SQL_VARCHAR to text rather than varchar(n)
	elsif( $data_type eq SQL_VARCHAR )
	{
		return {
			TYPE_NAME => "varchar",
			CREATE_PARAMS => "max length",
			COLUMN_SIZE => 255,
		};
	}
	elsif( $data_type eq SQL_LONGVARCHAR || $data_type eq SQL_CLOB )
	{
		return {
			TYPE_NAME => "text",
			CREATE_PARAMS => "",
			COLUMN_SIZE => 2**31,
		};
	}
	elsif( $data_type eq SQL_LONGVARBINARY )
	{
		return {
			TYPE_NAME => "bytea",
			CREATE_PARAMS => "",
			COLUMN_SIZE => 2**31,
		};
	}
	else
	{
		return $self->SUPER::type_info( $data_type );
	}
}

sub create
{
	my( $self, $username, $password ) = @_;

	my $repo = $self->{repository};

	my $dbh = DBI->connect( EPrints::Database::build_connection_string( 
			dbdriver => "Pg",
			dbhost => $repo->config("dbhost"),
			dbsock => $repo->config("dbsock"),
			dbport => $repo->config("dbport"),
			dbname => "postgres", ),
	        $username,
	        $password,
			{ AutoCommit => 1 } );

	return undef if !defined $dbh;

	my $dbuser = $repo->config( "dbuser" );
	my $dbpass = $repo->config( "dbpass" );
	my $dbname = $repo->config( "dbname" );

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

	return [ $bytes, { pg_type => DBD::Pg::PG_BYTEA } ];
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

sub sql_LIKE
{
	my( $self ) = @_;

	return " ILIKE ";
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

