######################################################################
#
# EPrints::Database::Oracle
#
######################################################################
#
#
######################################################################


=pod

=for Pod2Wiki

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

When specifying char column lengths use (n char) to define character semantics. Otherwise oracle uses the "nls_length_semantics" setting to determine whether you meant bytes or chars.

DBD::Oracle can crash when using PERL_USE_SAFE_PUTENV-compiled Perls, see http://www.eprints.org/tech.php/13984.html

=head2 TODO

=over 4

=item epadmin create

=item $name = $db->index_name( $table, @columns )

=back

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
		COLUMN_SIZE => 255,
	},
	SQL_LONGVARCHAR() => {
		CREATE_PARAMS => undef,
		TYPE_NAME => "CLOB",
		COLUMN_SIZE => 2**31,
	},
	SQL_CLOB() => {
		CREATE_PARAMS => undef,
		TYPE_NAME => "CLOB",
		COLUMN_SIZE => 2**31,
	},
	SQL_VARBINARY() => {
		CREATE_PARAMS => undef,
		TYPE_NAME => "BLOB",
		COLUMN_SIZE => 2**31,
	},
	SQL_LONGVARBINARY() => {
		CREATE_PARAMS => undef,
		TYPE_NAME => "BLOB",
		COLUMN_SIZE => 2**31,
	},
	SQL_TINYINT() => {
		CREATE_PARAMS => undef,
		TYPE_NAME => "NUMBER(3,0)",
		COLUMN_SIZE => 3,
	},
	SQL_SMALLINT() => {
		CREATE_PARAMS => undef,
		TYPE_NAME => "NUMBER(6,0)",
		COLUMN_SIZE => 6,
	},
	SQL_INTEGER() => {
		CREATE_PARAMS => undef,
		TYPE_NAME => "NUMBER(*,0)",
		COLUMN_SIZE => 10,
	},
	SQL_BIGINT() => {
		CREATE_PARAMS => undef,
		TYPE_NAME => "NUMBER(19,0)",
		COLUMN_SIZE => 19,
	},
	# NUMBER becomes FLOAT if not p,s is given
	SQL_REAL() => {
		CREATE_PARAMS => undef,
		TYPE_NAME => "NUMBER",
		COLUMN_SIZE => 15,
	},
	SQL_DOUBLE() => {
		CREATE_PARAMS => undef,
		TYPE_NAME => "NUMBER",
		COLUMN_SIZE => 15,
	},
	SQL_DATE() => {
		CREATE_PARAMS => undef,
		TYPE_NAME => "DATE",
		COLUMN_SIZE => 10,
	},
	SQL_TIME() => {
		CREATE_PARAMS => undef,
		TYPE_NAME => "DATE",
		COLUMN_SIZE => 10,
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
		# We then have to divide that by 4 to get the maximum UTF-8 length
		$length = 1000 if !defined($length) || $length > 1000;
	}

	my $type_info = $self->type_info( $data_type );
	$db_type = $type_info->{TYPE_NAME};
	$params = $type_info->{CREATE_PARAMS};

	my $type = $self->quote_identifier($name) . " " . $db_type;

	$params ||= "";
	if( $params eq "max length" )
	{
		EPrints::abort( "get_sql_type expected LENGTH argument for $data_type [$type]" )
			unless defined $length;
		if( $data_type eq SQL_VARCHAR() )
		{
			if( $length*4 > 4000 )
			{
				EPrints->abort( "Oracle does not support SQL_VARCHAR($length): maximum length is 1000 characters (4000 bytes)" );
			}
		}
		$type .= "($length char)";
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

	my $dbuser = $self->{repository}->config( "dbuser" );
	my $sql = "SELECT table_name FROM all_tables WHERE owner = ?";
	my $sth = $self->{dbh}->prepare($sql);
	return undef unless $sth;
	$sth->execute(uc($dbuser));

	while(my $row = $sth->fetchrow_arrayref)
	{
		my $name = $row->[0];
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

sub quote_ordervalue
{
	my( $self, $field, $value ) = @_;

	# maximum length of ordervalues column in Oracle is 1000 chars (4000 bytes)
	return defined $value ? substr($value,0,1000) : undef;
}

# unsupported
sub index_name
{
	my( $self, $table, @cols ) = @_;

	return 1;
}

sub sql_AS
{
	my( $self ) = @_;

	return " ";
}

sub retry_error
{
	my( $self ) = @_;

	my $err = $self->{'dbh'}->err;
	# ORA-03113: end-of-file on communication channel
	# ORA-03114: not connected to ORACLE
	return ($err == 3113) || ($err == 3114);
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
	my @types = $field->get_sql_type( $self->{repository} );

	return $rc if $self->has_column( $table, $names[0] ) && !$force;

	my @modify;
	my @add;
	for(my $i = 0; $i < @names; ++$i)
	{
		if( $self->has_column( $table, $names[$i] ) )
		{
			push @modify, $types[$i];
		}
		else
		{
			push @add, $types[$i];
		}
	}
	
	if( @modify )
	{
		$rc &&= $self->do( "ALTER TABLE ".$self->quote_identifier($table)." MODIFY (".join(",", @types).")");
	}
	if( @add )
	{
		$rc &&= $self->do( "ALTER TABLE ".$self->quote_identifier($table)." ADD (".join(",", @types).")");
	}

	if( my @columns = $field->get_sql_index )
	{
		$rc &&= $self->create_index( $table, @columns );
	}

	return $rc;
}

sub type_info
{
	my( $self, $data_type ) = @_;

	return $ORACLE_TYPES{$data_type};
}

sub drop_table
{
	my( $self, @tables ) = @_;

	local $self->{dbh}->{PrintError} = 0;
	local $self->{dbh}->{RaiseError} = 0;

	my $rc = 1;

	foreach my $table (@tables)
	{
		$rc &= defined $self->{dbh}->do( "DROP TABLE " .
				$self->quote_identifier($table) .
				" CASCADE CONSTRAINTS"
		);
	}

	return $rc;
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

