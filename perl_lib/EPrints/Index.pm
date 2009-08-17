######################################################################
#
# EPrints::Index
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

=item EPrints::Index::remove( $handle, $dataset, $objectid, $fieldid )

Remove all indexes to the field in the specified object.

=cut
######################################################################

sub remove
{
	my( $handle, $dataset, $objectid, $fieldid ) = @_;

	my $rv = 1;

	my $sql;

	my $db = $handle->get_database;

	my $keyfield = $dataset->get_key_field();
	my $Q_keyname = $db->quote_identifier( $keyfield->get_sql_name() );
	my $Q_field = $db->quote_identifier( "field" );
	my $Q_word = $db->quote_identifier( "word" );
	my $Q_fieldword = $db->quote_identifier( "fieldword" );
	my $Q_indextable = $db->quote_identifier($dataset->get_sql_index_table_name());
	my $Q_rindextable = $db->quote_identifier($dataset->get_sql_rindex_table_name());
	my $POS = $db->quote_identifier("pos");
	my $Q_ids = $db->quote_identifier("ids");

	my $where = "$Q_keyname=".$db->quote_value($objectid)." AND $Q_field=".$db->quote_value($fieldid);

	$sql = "SELECT $Q_word FROM $Q_rindextable WHERE $where";
	my $sth = $handle->get_database->prepare( $sql );
	$rv = $rv && $handle->get_database->execute( $sth, $sql );
	my @codes = ();
	while( my( $c ) = $sth->fetchrow_array )
	{
		push @codes,$c;
	}
	$sth->finish;

	foreach my $code ( @codes )
	{
		my $fieldword = $handle->{database}->quote_value( "$fieldid:$code" );
		my $sql = "UPDATE $Q_indextable SET $Q_ids = REPLACE($Q_ids,':$objectid:',':') WHERE $Q_fieldword=$fieldword AND $Q_ids LIKE ".$handle->{database}->quote_value("\%:$objectid:\%");
		$rv &&= $handle->{database}->do($sql);
	}
	$sql = "DELETE FROM $Q_rindextable WHERE $where";
	$rv = $rv && $handle->get_database->do( $sql );

	return $rv;
}

######################################################################
=pod

=item EPrints::Index::purge_index( $handle, $dataset )

Remove all the current index information for the given dataset. Only
really useful if used in conjunction with rebuilding the indexes.

=cut
######################################################################

sub purge_index
{
	my( $handle, $dataset ) = @_;

	$handle->clear_table( $dataset->get_sql_index_table_name() );
	$handle->clear_table( $dataset->get_sql_rindex_table_name() );
}


######################################################################
=pod

=item EPrints::Index::add( $handle, $dataset, $objectid, $fieldid, $value )

Add indexes to the field in the specified object. The index keys will
be taken from value.

=cut
######################################################################

sub add
{
	my( $handle, $dataset, $objectid, $fieldid, $value ) = @_;

	my $database = $handle->get_database;

	my $field = $dataset->get_field( $fieldid );

	my( $codes, $grepcodes, $ignored ) = $field->get_index_codes( $handle, $value );

	my %done = ();

	my $keyfield = $dataset->get_key_field();
	my $Q_keyname = $keyfield->get_sql_name();
	my $Q_field = $database->quote_identifier( "field" );
	my $Q_word = $database->quote_identifier( "word" );
	my $Q_fieldword = $database->quote_identifier( "fieldword" );
	my $Q_indextable = $database->quote_identifier($dataset->get_sql_index_table_name());
	my $Q_rindextable = $database->quote_identifier($dataset->get_sql_rindex_table_name());
	my $POS = $database->quote_identifier("pos");
	my $Q_ids = $database->quote_identifier("ids");


	my $indextable = $dataset->get_sql_index_table_name();
	my $rindextable = $dataset->get_sql_rindex_table_name();

	my $rv = 1;
	
	foreach my $code ( @{$codes} )
	{
		next if $done{$code};
		$done{$code} = 1;

		my $fieldword = $field->get_sql_name().":$code";
		my $where = "$Q_fieldword=".$database->quote_value($fieldword);

		my $sql = "SELECT MAX($POS) FROM $Q_indextable WHERE $where"; 
		my $sth = $handle->get_database->prepare( $sql );
		$rv = $rv && $handle->get_database->execute( $sth, $sql );
		return 0 unless $rv;
		my ( $n ) = $sth->fetchrow_array;
		$sth->finish;
		my $insert = 0;
		if( !defined $n )
		{
			$n = 0;
			$insert = 1;
		}
		else
		{
			$sql = "SELECT $Q_ids FROM $Q_indextable WHERE $where AND $POS=$n"; 
			$sth=$handle->get_database->prepare( $sql );
			$rv = $rv && $handle->get_database->execute( $sth, $sql );
			my( $ids ) = $sth->fetchrow_array;
			$sth->finish;
			my( @list ) = split( ":",$ids );
			# don't forget the first and last are empty!
			if( (scalar @list)-2 < 128 )
			{
				$sql = "UPDATE $Q_indextable SET $Q_ids='$ids$objectid:' WHERE $where AND $POS=$n";
				$rv = $rv && $handle->get_database->do( $sql );
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
			$rv &&= $handle->get_database->insert( $indextable, ["fieldword","pos","ids"], [
				$fieldword,
				$n,
				":$objectid:"
			]);
			return 0 unless $rv;
		}
		$rv &&= $handle->get_database->insert( $rindextable, ["field","word",$keyfield->get_sql_name()], [
			$field->get_sql_name,
			$code,
			$objectid
		]);
		return 0 unless $rv;

	} 

	my $name = $field->get_name;

	foreach my $grepcode ( @{$grepcodes} )
	{
		$handle->get_database->insert($dataset->get_sql_grep_table_name, [
			$keyfield->get_sql_name(),
			"fieldname",
			"grepstring"
		], [
			$objectid,
			$name,
			$grepcode
		]);
	}
}





######################################################################
=pod

=item EPrints::Index::update_ordervalues( $handle, $dataset, $data )

Update the order values for an object. $data is a structure
returned by $dataobj->get_data

=cut
######################################################################

# $tmp should not be used any more.

sub update_ordervalues
{
	my( $handle, $dataset, $data, $tmp ) = @_;

	&_do_ordervalues( $handle, $dataset, $data, 0, $tmp );	
}

######################################################################
=pod

=item EPrints::Index::insert_ordervalues( $handle, $dataset, $data )

Create the order values for an object. $data is a structure
returned by $dataobj->get_data

=cut
######################################################################

sub insert_ordervalues
{
	my( $handle, $dataset, $data, $tmp ) = @_;

	&_do_ordervalues( $handle, $dataset, $data, 1, $tmp );	
}

# internal method to avoid code duplication. Update and insert are
# very similar.

sub _do_ordervalues
{
        my( $handle, $dataset, $data, $insert, $tmp ) = @_;

	# insert is ignored
	# insert = 0 => update
	# insert = 1 => insert
	# tmp = 1 = use_tmp_table
	# tmp = 0 = use normal table

	my( $keyfield, @fields ) = $dataset->get_fields( 1 );
	my $keyname = $keyfield->get_sql_name;
	my $keyvalue = $data->{$keyfield->get_name()};

	foreach my $langid ( @{$handle->get_repository->get_conf( "languages" )} )
	{
		my $ovt = $dataset->get_ordervalues_table_name( $langid );
		if( $tmp ) { $ovt .= "_tmp"; }

		my @fnames = ( $keyname );
		my @fvals = ( $keyvalue );
		foreach my $field ( @fields )
		{
			my $ov = $field->ordervalue( 
					$data->{$field->get_name()},
					$handle,
					$langid,
					$dataset );
			
			push @fnames, $field->get_sql_name();
			push @fvals, $ov;
		}

		if( !$insert )
		{
			$handle->get_database->delete_from( $ovt, [$keyname], [$keyvalue] );
		}
		$handle->get_database->insert( $ovt, \@fnames, \@fvals );
	}
}

######################################################################
=pod

=item EPrints::Index::delete_ordervalues( $handle, $dataset, $id )

Remove the ordervalues for item $id from the ordervalues table of
$dataset.

=cut
######################################################################

sub delete_ordervalues
{
	my( $handle, $dataset, $id, $tmp ) = @_;

	my $db = $handle->get_database;

	my @fields = $dataset->get_fields( 1 );

	# remove the key field
	splice( @fields, 0, 1 ); 
	my $keyfield = $dataset->get_key_field();
	my $keyvalue = $id;

	foreach my $langid ( @{$handle->get_repository->get_conf( "languages" )} )
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

sub do_index
{
	my( $handle, $p ) = @_;

	my $seen_action = 0; # have we done anything
	my $loop_max = 10; # max times to loop

	my $index_queue = $handle->get_repository->get_dataset( "index_queue" );
	my $searchexp = EPrints::Search->new(
		allow_blank => 1,
		handle => $handle,
		dataset => $index_queue,
		);
	my $list = $searchexp->perform_search();

	foreach my $iq ($list->get_records(0,$loop_max))
	{
		$seen_action = 1;

		my $datasetid = $iq->get_value( "datasetid" );
		my $objectid = $iq->get_value( "objectid" );
		my $fieldid = $iq->get_value( "fieldid" );
		my $fieldcode = "$datasetid.$objectid.$fieldid"; # for debug messages

		$iq->remove();
	
		my $dataset = $handle->get_repository->get_dataset( $datasetid );
		if( !defined $dataset )
		{
			EPrints::Index::indexlog( "Could not make dataset: $datasetid ($fieldcode)" );
			next;
		}

		my $item = $dataset->get_object( $handle, $objectid );
		next unless ( defined $item );

		my @fields;

		if( $fieldid eq EPrints::DataObj::IndexQueue::ALL() )
		{
			push @fields, $dataset->get_fields();
		}
		elsif( $fieldid eq EPrints::DataObj::IndexQueue::FULLTEXT() )
		{
			push @fields, EPrints::MetaField->new( 
				dataset => $dataset, 
				name => $fieldid,
				multiple => 1,
				type => "fulltext" );
		}
		else
		{
			if( defined(my $field = $dataset->get_field( $fieldid )) )
			{
				push @fields, $field;
			}
		}
		if( !scalar @fields )
		{
			EPrints::Index::indexlog( "No such field: $fieldid (found on index queue).. skipping.\n" );
			next;
		}
	
		foreach my $field (@fields)
		{
			EPrints::Index::indexlog( "* de-indexing: $fieldcode" ) if( $p->{loglevel} > 4 );
			EPrints::Index::remove( $handle, $dataset, $objectid, $field->get_name() );
			EPrints::Index::indexlog( "* done-de-indexing: $fieldcode" ) if( $p->{loglevel} > 5 );

			next unless( $field->get_property( "text_index" ) );

			my $value = $field->get_value( $item );
		
			next unless EPrints::Utils::is_set( $value );	

			EPrints::Index::indexlog( "* indexing: $fieldcode" ) if( $p->{loglevel} > 4 );
			EPrints::Index::add( $handle, $dataset, $objectid, $field->get_name(), $value );
			EPrints::Index::indexlog( "* done-indexing: $fieldcode" ) if( $p->{loglevel} > 5 );
		}
	};

	$searchexp->dispose();

	return $seen_action;
}	

1;

######################################################################
=pod

=back

=cut

