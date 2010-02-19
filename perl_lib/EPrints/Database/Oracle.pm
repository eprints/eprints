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

=head1 SYNOPSIS

These settings are the default settings for the free Oracle developer version:

	# Oracle driver settings for database.pl
	$c->{dbdriver} = "Oracle";
	$c->{dbhost} = "localhost";
	$c->{dbsid} = "XE;
	$c->{dbuser} = "HR";
	$c->{dbpass} = "HR";

=head1 DESCRIPTION

Oracle database wrapper for Oracle DB version 9+.

=head2 Setting up Oracle

Enable the HR user in Oracle XE.

Set the ORACLE_HOME and ORACLE_SID environment variables. To add these globally edit /etc/profile.d/oracle.sh (for XE edition):

	export ORACLE_HOME="/usr/lib/oracle/xe/app/oracle/product/10.2.0/server"
	export ORACLE_SID="XE"

(Will need to relog to take effect)

=head2 Oracle-specific Annoyances

Use the GQLPlus wrapper from http://gqlplus.sourceforge.net/ instead of sqlplus.

Oracle will uppercase any identifiers that aren't quoted and is case sensitive, hence mixing quoted and unquoted identifiers will lead to problems.

Oracle does not support LIMIT().

Oracle does not support AUTO_INCREMENT (MySQL) nor SERIAL (Postgres).

Oracle won't ORDER BY LOBS.

Oracle requires special means to insert values into CLOB/BLOB.

Oracle doesn't support "AS" when aliasing.

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

$ENV{NLS_LANG} = ".AL32UTF8";
$ENV{NLS_NCHAR} = "AL32UTF8";

use EPrints;

use EPrints::Database qw( :sql_types );
@ISA = qw( EPrints::Database );

our $I18L = {};

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
	SQL_BIGINT() => {
		CREATE_PARAMS => undef,
		TYPE_NAME => "NUMBER(19,0)",
	},
	# NUMBER becomes FLOAT if not p,s is given
	SQL_REAL() => {
		CREATE_PARAMS => undef,
		TYPE_NAME => "NUMBER",
	},
	SQL_DOUBLE() => {
		CREATE_PARAMS => undef,
		TYPE_NAME => "NUMBER",
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

	$self->{dbh}->{LongReadLen} = 128*1024;
}

sub prepare_select
{
	my( $self, $sql, %options ) = @_;

	if( defined $options{limit} && length($options{limit}) )
	{
		if( defined $options{offset} && length($options{offset}) )
		{
			my $upper = $options{offset} + $options{limit};
			$sql = "SELECT *\n"
				.  "FROM (\n"
				.  "  SELECT /*+ FIRST_ROWS($upper) */ query__.*, ROWNUM rnum__\n"
				.  "  FROM (\n"
				.     $sql ."\n"
				.  "  ) query__\n"
				.  "  WHERE ROWNUM <= $upper)\n"
				.  "WHERE rnum__  > $options{offset}";
		}
		else
		{
			my $upper = $options{limit} + 0;
			$sql = "SELECT /*+ FIRST_ROWS($upper) */ query__.*\n"
				.  "FROM (\n"
				.   $sql ."\n"
				.  ") query__\n"
				.  "WHERE ROWNUM <= $upper";
		}
	}

	return $self->prepare( $sql );
}

sub create_archive_tables
{
	my( $self ) = @_;

	{
		local $self->{dbh}->{RaiseError};
		local $self->{dbh}->{PrintError};
		my( $rc ) = $self->{dbh}->selectrow_array( "SELECT 1 FROM dual" );
		if( $rc != 1 )
		{
			EPrints::abort( "It appears the magic 'dual' table isn't available in the database. Contact your Oracle admin." );
		}
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
	my( $self, $name, $data_type, $not_null, $length, $scale, %opts ) = @_;

	my( $db_type, $params ) = (undef, "");

	# Oracle can't order a LONG column, so we'll switch to the best we can
	# do instead, which is a 4000 byte VARCHAR
	if( $opts{sorted} )
	{
		if( $data_type eq SQL_LONGVARCHAR() )
		{
			$data_type = SQL_VARCHAR();
		}
		elsif( $data_type eq SQL_LONGVARBINARY() )
		{
			$data_type = SQL_VARBINARY();
		}
		# Longest VARCHAR supported by Oracle is 4096 bytes (4000 in practise?)
		$length = 4000 if !defined($length) || $length > 4000;
	}

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
	my $sth = $self->{dbh}->table_info( '%', uc($dbuser), '%', 'TABLE' );

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

	$name = substr($self->quote_identifier( $name ),1,-1);

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

	$table = substr($self->quote_identifier( $table ),1,-1);
	$column = substr($self->quote_identifier( $column ),1,-1);

	my $sql = "SELECT 1 FROM USER_TAB_COLUMNS WHERE TABLE_NAME=".$self->quote_value( $table )." AND COLUMN_NAME=".$self->quote_value( $column );
	my $rows = $self->{dbh}->selectall_arrayref( $sql );

	return scalar @$rows;
}

sub has_table
{
	my( $self, $table ) = @_;

	$table = substr($self->quote_identifier( $table ),1,-1);

	my $sql = "SELECT 1 FROM USER_TABLES WHERE TABLE_NAME=".$self->quote_value( $table );
	my $rows = $self->{dbh}->selectall_arrayref( $sql );

	return scalar @$rows;
}

# Oracle doesn't support getting the "current" value of a sequence
sub counter_current
{
	my( $self, $counter ) = @_;

	return undef;
}

=item $id = $db->quote_identifier( $col [, $col ] )

This method quotes and returns the given database identifier. If more than one name is supplied joins them using the correct database join character (typically '.').

Oracle restricts identifiers to:

 	30 chars long
 	start with a letter [a-z]
 	{ [a-z0-9], $, _, # }
 	case insensitive
 	not a reserved word (unless quoted?)

Identifiers longer than 30 chars will be abbreviated to the first 5 chars of the identifier and 25 characters from an MD5 derived from the identifier. This should make name collisions unlikely.

=cut

sub quote_identifier
{
	return join(".", map {
		'"'.uc($_).'"' # foo or FOO == "FOO"
		} map {
			length($_) <= 30 ?
			$_ :
			substr($_,0,5).substr(Digest::MD5::md5_hex( $_ ),0,25) # hex MD5 is 32 chars long
		} @_[1..$#_]);
}

sub prepare_regexp
{
	my ($self, $col, $value) = @_;

	return "REGEXP_LIKE ($col, $value)";
}

sub quote_binary
{
	my( $self, $value ) = @_;

	use bytes;

	return join('', map { sprintf("%02x",ord($_)) } split //, $value);
}

# unsupported
sub index_name
{
	my( $self, $table, @cols ) = @_;

	return 1;
}

sub alias_glue
{
	my( $self ) = @_;

	return " ";
}

1; # For use/require success

######################################################################
=pod

=back

=cut

