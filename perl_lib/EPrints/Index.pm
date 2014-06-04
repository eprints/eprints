######################################################################
#
# EPrints::Index
#
######################################################################
#
#
######################################################################


=pod

=head1 NAME

B<EPrints::Index> - Methods for indexing objects for later searching.

=head1 DESCRIPTION

This module contains methods used to add and remove information from
the free-text search indexes. 

=head1 FUNCTIONS

=over 4

=cut


package EPrints::Index;

use EPrints::Index::Tokenizer; # split_words,apply_mapping back-compatibility
use POSIX 'setsid';
use EPrints;
use strict;


######################################################################
=pod

=item EPrints::Index::remove( $session, $dataset, $objectid, $fieldid )

Remove all indexes to the field in the specified object.

=cut
######################################################################

sub remove
{
	my( $session, $dataset, $objectid, $fieldids ) = @_;

# sf2
	EPrints->trace( 'Deprecated Index::remove called' );
	return 1;

	$fieldids = [$fieldids] if ref($fieldids) ne "ARRAY";

	my $rv = 1;

	my $sql;

	my $db = $session->get_database;

	my $rindextable = $dataset->get_sql_rindex_table_name();
	my $grepindextable = $dataset->get_sql_grep_table_name();

	my $keyfield = $dataset->key_field();

	# remove from rindex table
	$db->do(
		"DELETE FROM " . 
			$db->quote_identifier( $rindextable ) . 
		" WHERE " . 
			$db->quote_identifier( $keyfield->get_sql_name )."=".$db->quote_value( $objectid ) . 
			" AND " . 
			$db->quote_identifier( "field" )." IN (".join(',', map { $db->quote_value( $_ ) } @$fieldids).")"
	);

	# remove from grep table
	$db->do(
		"DELETE FROM " . 
			$db->quote_identifier( $grepindextable ) . 
		" WHERE " . 
			$db->quote_identifier( $keyfield->get_sql_name )."=".$db->quote_value( $objectid ) . 
			" AND " . 
			$db->quote_identifier( "fieldname" )." IN (".join(',', map { $db->quote_value( $_ ) } @$fieldids).")"
	);

	return $rv;
}

=item $ok = EPrints::Index::remove_all( $session, $dataset, $objectid )

Remove all indexes to the specified object.

=cut

sub remove_all
{
	my( $session, $dataset, $objectid ) = @_;

# sf2
	EPrints->trace( 'Deprecated Index::remove_all called' );
	return 1;

	my $rv = 1;

	my $sql;

	my $db = $session->get_database;

	my $rindextable = $dataset->get_sql_rindex_table_name();
	my $grepindextable = $dataset->get_sql_grep_table_name();

	my $keyfield = $dataset->key_field();

	# remove from rindex table
	$db->delete_from($rindextable,
		[ $keyfield->get_sql_name() ],
		[ $objectid ] );

	# remove from grep table
	$db->delete_from($grepindextable,
		[ $keyfield->get_sql_name ],
		[ $objectid ] );

	return $rv;
}

######################################################################
=pod

=item EPrints::Index::purge_index( $session, $dataset )

Remove all the current index information for the given dataset. Only
really useful if used in conjunction with rebuilding the indexes.

=cut
######################################################################

# Unused?
sub purge_index
{
	my( $session, $dataset ) = @_;

# sf2
	EPrints->trace( 'Deprecated Index::purge_index called' );
	return 1;

	$session->clear_table( $dataset->get_sql_rindex_table_name() );
	$session->clear_table( $dataset->get_sql_grep_table_name() );
}


######################################################################
=pod

=item EPrints::Index::add( $session, $dataset, $objectid, $fieldid, $value )

Add indexes to the field in the specified object. The index keys will
be taken from value.

=cut
######################################################################

sub add
{
	my( $session, $dataset, $objectid, $fieldid, $value ) = @_;

# sf2
	EPrints->trace( 'Deprecated Index::add called' );
	return 1;

	my $db = $session->get_database;

	my $field = $dataset->get_field( $fieldid );

	my( $codes, $grepcodes, $ignored ) = $field->get_index_codes( $session, $value );

	# get rid of duplicates
	my %done = ();
	@$codes = grep { !$done{$_}++ } @$codes;
	%done = ();
	@$grepcodes = grep { !$done{$_}++ } @$grepcodes;

	my $keyfield = $dataset->key_field();

	my $rindextable = $dataset->get_sql_rindex_table_name();
	my $grepindextable = $dataset->get_sql_grep_table_name();

	my $rv = 1;
	
	$rv &&= $db->insert( $rindextable, [
		$keyfield->get_sql_name(),
		"field",
		"word"
	], map { [ $objectid, $fieldid, $_ ] } @$codes );

	$rv &&= $db->insert($grepindextable, [
		$keyfield->get_sql_name(),
		"fieldname",
		"grepstring"
	], map { [ $objectid, $fieldid, $_ ] } @$grepcodes );

	return $rv;
}





######################################################################
=pod

=item EPrints::Index::update_ordervalues( $session, $dataset, $data, $changed )

Update the order values for an object. $data is a structure
returned by $dataobj->get_data. $changed is a hash of changed fields.

=cut
######################################################################

sub update_ordervalues
{
	my( $session, $dataset, $data, $changed ) = @_;

# sf2
	EPrints->trace( 'Deprecated Index::update_ordervalues called' );
	return 1;

	&_do_ordervalues( $session, $dataset, $data, $changed, 0 );
}

######################################################################
=pod

=item EPrints::Index::insert_ordervalues( $session, $dataset, $data )

Create the order values for an object. $data is a structure
returned by $dataobj->get_data

=cut
######################################################################

sub insert_ordervalues
{
	my( $session, $dataset, $data ) = @_;

	&_do_ordervalues( $session, $dataset, $data, $data, 1 );	
}

# internal method to avoid code duplication. Update and insert are
# very similar.

sub _do_ordervalues
{
    my( $session, $dataset, $data, $changed, $insert ) = @_;
	
# sf2
	EPrints->trace( 'Deprecated Index::_do_ordervalues called' );
	return 1;

	# nothing to do
	return 1 if !keys %$changed;

	# insert is ignored
	# insert = 0 => update
	# insert = 1 => insert

	my $keyfield = $dataset->key_field;
	my $keyname = $keyfield->get_sql_name;
	my $keyvalue = $data->{$keyfield->get_name()};

	foreach my $langid ( @{$session->config( "languages" )} )
	{
		my $ovt = $dataset->get_ordervalues_table_name( $langid );

		my @fnames;
		my @fvals;
		foreach my $fieldname ( keys %$changed )
		{
			next if $fieldname eq $keyname;
			my $field = $dataset->field( $fieldname );
			next if $field->is_virtual;

			my $ov = $field->ordervalue( 
					$data->{$fieldname},
					$session,
					$langid,
					$dataset );
			
			push @fnames, $field->get_sql_name();
			push @fvals, $ov;
		}

		if( $insert )
		{
			$session->get_database->insert( $ovt,
				[$keyname, @fnames],
				[$keyvalue, @fvals] );
		}
		elsif( @fnames )
		{
			$session->get_database->_update( $ovt,
				[$keyname],
				[$keyvalue],
				\@fnames,
				\@fvals );
		}
	}
}

######################################################################
=pod

=item EPrints::Index::delete_ordervalues( $session, $dataset, $id )

Remove the ordervalues for item $id from the ordervalues table of
$dataset.

=cut
######################################################################

sub delete_ordervalues
{
	my( $session, $dataset, $id, $tmp ) = @_;
	
# sf2
	EPrints->trace( 'Deprecated Index::delete_ordervalues called' );
	return 1;

	my $db = $session->get_database;

	my @fields = $dataset->get_fields( 1 );

	# remove the key field
	splice( @fields, 0, 1 ); 
	my $keyfield = $dataset->key_field();
	my $keyvalue = $id;

	foreach my $langid ( @{$session->config( "languages" )} )
	{
		# cjg raw SQL!
		my $ovt = $dataset->get_ordervalues_table_name( $langid );
		if( $tmp ) { $ovt .= "_tmp"; }
		my $sql;
		$sql = "DELETE FROM ".$db->quote_identifier($ovt)." WHERE ".$db->quote_identifier($keyfield->get_sql_name())."=".$db->quote_value( $keyvalue );
		$db->do( $sql );
	}
}

sub pidfile
{
	return EPrints::Config::get("var_path")."/indexer.pid";
}

sub tickfile
{
	return EPrints::Config::get("var_path")."/indexer.tick";
}

sub logfile
{
	return EPrints::Config::get("var_path")."/indexer.log";
}

sub binfile
{
	return EPrints::Config::get("bin_path")."/indexer";
}

sub suicidefile
{
	return EPrints::Config::get("var_path")."/indexer.suicide";
}

sub indexlog
{
	my( $txt ) = @_;

	if( !defined $txt )
	{
		print STDERR "\n";
		return;
	}

	print STDERR "[".localtime()."] ".$txt."\n";
}

1;

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

