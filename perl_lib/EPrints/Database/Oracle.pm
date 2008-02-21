######################################################################
#
# EPrints::Database::Oracle
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

B<EPrints::Database::Oracle> - custom database methods for Oracle DB

=head1 DESCRIPTION

Oracle database wrapper.

=head2 Oracle-specific Annoyances

Oracle will uppercase any identifiers that aren't quoted and is case sensitive, hence mixing quoted and unquoted identifiers will lead to problems.

Oracle does not support LIMIT().

Oracle does not support AUTO_INCREMENT (MySQL) nor SERIAL (Postgres).

Oracle won't ORDER BY LOBS.

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

package EPrints::Database::Oracle;

use EPrints;

use EPrints::Database qw( :sql_types );
@ISA = qw( EPrints::Database );

# DBD::Oracle seems to not be very good on type_info
our %ORACLE_TYPES = (
	SQL_VARCHAR() => {
		CREATE_PARAMS => "max length",
		TYPE_NAME => "VARCHAR2",
	},
	SQL_LONGVARCHAR() => {
		CREATE_PARAMS => undef,
		TYPE_NAME => "CLOB",
	},
	SQL_VARBINARY() => {
		CREATE_PARAMS => undef,
		TYPE_NAME => "BLOB",
	},
	SQL_LONGVARBINARY() => {
		CREATE_PARAMS => undef,
		TYPE_NAME => "BLOB",
	},
	SQL_TINYINT() => {
		CREATE_PARAMS => undef,
		TYPE_NAME => "NUMBER(3,0)",
	},
	SQL_SMALLINT() => {
		CREATE_PARAMS => undef,
		TYPE_NAME => "NUMBER(6,0)",
	},
	SQL_INTEGER() => {
		CREATE_PARAMS => undef,
		TYPE_NAME => "NUMBER(*,0)",
	},
	SQL_REAL() => {
		CREATE_PARAMS => undef,
		TYPE_NAME => "BINARY_FLOAT",
	},
	SQL_DOUBLE() => {
		CREATE_PARAMS => undef,
		TYPE_NAME => "BINARY_DOUBLE",
	},
	SQL_DATE() => {
		CREATE_PARAMS => undef,
		TYPE_NAME => "DATE",
	},
	SQL_TIME() => {
		CREATE_PARAMS => undef,
		TYPE_NAME => "DATE",
	},
);

use strict;

sub connect
{
	my( $self ) = @_;

	return unless $self->SUPER::connect();

	$self->{dbh}->{LongReadLen} = 2048;
}

sub create_archive_tables
{
	my( $self ) = @_;

	# dual is a 'dummy' table to allow SELECT <function> FROM dual
	if( !$self->has_table( "dual" ) )
	{
		$self->_create_table( "dual", [], ["DUMMY VARCHAR2(1)"] );
		$self->do("INSERT INTO \"dual\" VALUES ('X')");
	}

	return $self->SUPER::create_archive_tables();
}

######################################################################
=pod

=item $version = $db->get_server_version

Return the database server version.

=cut
######################################################################

sub get_server_version
{
	my( $self ) = @_;

	my $sql = "SELECT * from V\$VERSION WHERE BANNER LIKE 'Oracle%'";
	my( $version ) = $self->{dbh}->selectrow_array( $sql );
	return $version;
}

######################################################################
=pod

=item $real_type = $db->get_column_type( NAME, TYPE, NOT_NULL, [, LENGTH ] )

Returns a column definition for NAME of type TYPE. If NOT_NULL is true the column will be created NOT NULL. For column types that require a length use LENGTH.

TYPE is the SQL type. The types are constants defined by this module, to import them use:

  use EPrints::Database qw( :sql_types );

Supported types (n = requires LENGTH argument):

Character data: SQL_VARCHAR(n), SQL_LONGVARCHAR.

Binary data: SQL_VARBINARY(n), SQL_LONGVARBINARY.

Integer data: SQL_TINYINT, SQL_SMALLINT, SQL_INTEGER.

Floating-point data: SQL_REAL, SQL_DOUBLE.

Time data: SQL_DATE, SQL_TIME.

=cut
######################################################################

sub get_column_type
{
	my( $self, $name, $data_type, $not_null, $length, $scale ) = @_;

	my( $db_type, $params ) = (undef, "");

	$db_type = $ORACLE_TYPES{$data_type}->{TYPE_NAME};
	$params = $ORACLE_TYPES{$data_type}->{CREATE_PARAMS};

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

	if( $not_null )
	{
		$type .= " NOT NULL";
	}

	return $type;
}

sub index_dequeue
{
	my( $self ) = @_;

	my $Q_field = $self->quote_identifier( "field" );
	my $Q_table = $self->quote_identifier( "index_queue" );
	my $Q_added = $self->quote_identifier( "added" );

	# Oracle doesn't support LIMIT
	my $sql = "SELECT $Q_field FROM (SELECT ROWNUM \"ID\",$Q_field FROM $Q_table ORDER BY $Q_added ASC) WHERE \"ID\"=1";
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

=item @tables = $db->get_tables

Return a list of all the tables in the database.

=cut
######################################################################

sub get_tables
{
	my( $self ) = @_;

	my @tables;

	my $dbuser = $self->{session}->get_repository->get_conf( "dbuser" );
	my $sth = $self->{dbh}->table_info( '%', $dbuser, '%', 'TABLE' );

	while(my $row = $sth->fetch)
	{
		my $name = $row->[$sth->{NAME_lc_hash}{table_name}];
		next if $name =~ /\$/;
		push @tables, $name;
	}
	$sth->finish;

	return @tables;
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

	my $sql = "SELECT 1 FROM ALL_SEQUENCES WHERE SEQUENCE_NAME=?";
	my $sth = $self->prepare($sql);
	$sth->execute( $name );

	return $sth->fetch ? 1 : 0;
}

######################################################################
=pod

=item $boolean = $db->has_column( $tablename, $columnname )

Return true if the a table of the given name has a column named $columnname in the database.

=cut
######################################################################

# Default method is really, really slow
sub has_column
{
	my( $self, $table, $column ) = @_;

	my $rc = 1;

	my $sql = "SELECT 1 FROM USER_TAB_COLUMNS WHERE ".
		"TABLE_NAME=".$self->quote_value( $table )." AND ".
		"COLUMN_NAME=".$self->quote_value( $column );
	my $sth = $self->prepare( $sql );
	$sth->execute;
	$rc = $sth->fetch ? 1 : 0;
	$sth->finish;

	return $rc;
}

1; # For use/require success

######################################################################
=pod

=back

=cut

