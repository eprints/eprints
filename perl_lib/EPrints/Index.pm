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

=item EPrints::Index::remove( $session, $dataset, $objectid, $fieldid )

Remove all indexes to the field in the specified object.

=cut
######################################################################

sub remove
{
	my( $session, $dataset, $objectid, $fieldid ) = @_;

	my $rv = 1;

	my $sql;

	my $db = $session->get_database;

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
	my $sth = $session->get_database->prepare( $sql );
	$rv = $rv && $session->get_database->execute( $sth, $sql );
	my @codes = ();
	while( my( $c ) = $sth->fetchrow_array )
	{
		push @codes,$c;
	}
	$sth->finish;

	foreach my $code ( @codes )
	{
		my $fieldword = $session->{database}->quote_value( "$fieldid:$code" );
		my $sql = "UPDATE $Q_indextable SET $Q_ids = REPLACE($Q_ids,':$objectid:',':') WHERE $Q_fieldword=$fieldword AND $Q_ids LIKE ".$session->{database}->quote_value("\%:$objectid:\%");
		$rv &&= $session->{database}->do($sql);
	}
	$sql = "DELETE FROM $Q_rindextable WHERE $where";
	$rv = $rv && $session->get_database->do( $sql );

	return $rv;
}

######################################################################
=pod

=item EPrints::Index::purge_index( $session, $dataset )

Remove all the current index information for the given dataset. Only
really useful if used in conjunction with rebuilding the indexes.

=cut
######################################################################

sub purge_index
{
	my( $session, $dataset ) = @_;

	$session->clear_table( $dataset->get_sql_index_table_name() );
	$session->clear_table( $dataset->get_sql_rindex_table_name() );
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

	my $database = $session->get_database;

	my $field = $dataset->get_field( $fieldid );

	my( $codes, $grepcodes, $ignored ) = $field->get_index_codes( $session, $value );

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
		my $sth = $session->get_database->prepare( $sql );
		$rv = $rv && $session->get_database->execute( $sth, $sql );
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
			$sth=$session->get_database->prepare( $sql );
			$rv = $rv && $session->get_database->execute( $sth, $sql );
			my( $ids ) = $sth->fetchrow_array;
			$sth->finish;
			my( @list ) = split( ":",$ids );
			# don't forget the first and last are empty!
			if( (scalar @list)-2 < 128 )
			{
				$sql = "UPDATE $Q_indextable SET $Q_ids='$ids$objectid:' WHERE $where AND $POS=$n";
				$rv = $rv && $session->get_database->do( $sql );
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
			$rv &&= $session->get_database->insert( $indextable, ["fieldword","pos","ids"], [
				$fieldword,
				$n,
				":$objectid:"
			]);
			return 0 unless $rv;
		}
		$rv &&= $session->get_database->insert( $rindextable, ["field","word",$keyfield->get_sql_name()], [
			$field->get_sql_name,
			$code,
			$objectid
		]);
		return 0 unless $rv;

	} 

	my $name = $field->get_name;

	foreach my $grepcode ( @{$grepcodes} )
	{
		$session->get_database->insert($dataset->get_sql_grep_table_name, [
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

=item EPrints::Index::update_ordervalues( $session, $dataset, $data )

Update the order values for an object. $data is a structure
returned by $dataobj->get_data

=cut
######################################################################

# $tmp should not be used any more.

sub update_ordervalues
{
	my( $session, $dataset, $data, $tmp ) = @_;

	&_do_ordervalues( $session, $dataset, $data, 0, $tmp );	
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
	my( $session, $dataset, $data, $tmp ) = @_;

	&_do_ordervalues( $session, $dataset, $data, 1, $tmp );	
}

# internal method to avoid code duplication. Update and insert are
# very similar.

sub _do_ordervalues
{
        my( $session, $dataset, $data, $insert, $tmp ) = @_;

	# insert is ignored
	# insert = 0 => update
	# insert = 1 => insert
	# tmp = 1 = use_tmp_table
	# tmp = 0 = use normal table

	my( $keyfield, @fields ) = $dataset->get_fields( 1 );
	my $keyname = $keyfield->get_sql_name;
	my $keyvalue = $data->{$keyfield->get_name()};

	foreach my $langid ( @{$session->get_repository->get_conf( "languages" )} )
	{
		my $ovt = $dataset->get_ordervalues_table_name( $langid );
		if( $tmp ) { $ovt .= "_tmp"; }

		my @fnames = ( $keyname );
		my @fvals = ( $keyvalue );
		foreach my $field ( @fields )
		{
			my $ov = $field->ordervalue( 
					$data->{$field->get_name()},
					$session,
					$langid,
					$dataset );
			
			push @fnames, $field->get_sql_name();
			push @fvals, $ov;
		}

		if( !$insert )
		{
			$session->get_database->delete_from( $ovt, [$keyname], [$keyvalue] );
		}
		$session->get_database->insert( $ovt, \@fnames, \@fvals );
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

	my $db = $session->get_database;

	my @fields = $dataset->get_fields( 1 );

	# remove the key field
	splice( @fields, 0, 1 ); 
	my $keyfield = $dataset->get_key_field();
	my $keyvalue = $id;

	foreach my $langid ( @{$session->get_repository->get_conf( "languages" )} )
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

sub do_tick
{
	my $tickfile = EPrints::Index::tickfile();
	open( TICK, ">$tickfile" );
	print TICK <<END;
# This file is recreated by the indexer to indicate
# that the indexer is still running.
END
	close TICK;
}

sub write_pid
{
	my $pidfile = EPrints::Index::pidfile();
	open( PID, ">$pidfile" ) || EPrints::abort( "Can't open $pidfile for writing: $!" );
	print PID <<END;
# This file is automatically generated to indicate what process ID
# indexer is running as. If this file exists then indexer is assumed
# to be running.
END
	print PID $$."\n";
	print PID EPrints::Time::human_time()."\n";
	close PID;
}

sub get_pid
{
	my $pidfile = EPrints::Index::pidfile();
#	print "Reading $p->{pidfile}\n" if( $p->{noise} > 1 );
	open( PID, $pidfile ) || EPrints::abort( "Could not open $pidfile: $!" );
	my $pid;
	while( <PID> )
	{
		s/\015?\012?$//s;
		if( m/^\d+$/ )
		{
			$pid = $_;
			last;
		}
	}
	close PID;

	return $pid;
}

sub has_stalled
{
	my $last_tick = EPrints::Index::get_last_tick();
	return 1 if( $last_tick > 10*60 );
	return 0;
}

sub get_last_tick
{
	my $tickfile = tickfile();
	return undef unless( -e $tickfile );

	# Comes back in fractions of days, so rescale	
	my $age = ( -M $tickfile );
	return $age*24*60*60;
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

sub rolllogs
{
	my( $p ) = @_;

	return if( $p->{loglevel} <= 0 );
	return if( $p->{rollcount} <= 0 );

	EPrints::Index::indexlog( "** End of log. Closing and rolling." ) if( $p->{loglevel} > 2 );
	for( my $n = $p->{rollcount}; $n > 0; --$n )
	{
		my $src = $p->{logfile};	
		if( $n > 1 ) { $src.='.'.($n-1); }
		next unless( -f $src );
		my $tgt = $p->{logfile}.'.'.$n;
		rename( $src, $tgt ) || warn "Error renaming: $!";
	}
	close STDERR;
	open( STDERR, ">>$p->{logfile}" ) || warn "Error opening: $p->{logfile}: $!";
	select( STDERR );
	$| = 1;
}


sub cleanup_indexer
{
	my( $p ) = @_;

	EPrints::Index::indexlog( "** Control process $$ stopping..." ) if( $p->{loglevel} > 2 );
	EPrints::Index::indexlog( "* Unlinking $p->{pidfile}" ) if( $p->{loglevel} > 3 );
	unlink( $p->{pidfile} ) || die( "Can't unlink $p->{pidfile}" );
	unlink( $p->{tickfile} ) || die( "Can't unlink $p->{tickfile}" );
	if( defined $p->{kid} )
	{
		EPrints::Index::indexlog( "* Sending TERM signal to worker process: $p->{kid}" ) if( $p->{loglevel} > 2 );
		kill 15, $p->{kid};
	}

	if( EPrints::Index::suicidal() ) 
	{
		unlink( EPrints::Index::suicidefile() );
	}

	EPrints::Index::indexlog( "** Control process $$ stopped", 1 ) if( $p->{loglevel} > 2 );
	EPrints::Index::indexlog( "**** Indexer stopped" ) if( $p->{loglevel} > 0 );
	EPrints::Index::indexlog() if( $p->{loglevel} > 0 );
}



sub do_index
{
	my( $session, $p ) = @_;

	my $seen_action = 0; # have we done anything
	my $loop_max = 10; # max times to loop

	while(
		$loop_max-- and
		my( $datasetid, $objectid, $fieldid ) = $session->get_database->index_dequeue()
	)
	{
		$seen_action = 1;
		my $fieldcode = "$datasetid.$objectid.$fieldid"; # for debug messages
	
		my $dataset = $session->get_repository->get_dataset( $datasetid );
		if( !defined $dataset )
		{
			EPrints::Index::indexlog( "Could not make dataset: $datasetid ($fieldcode)" );
			next;
		}
		my $field = $dataset->get_field( $fieldid );
		if( !defined $field )
		{
			EPrints::Index::indexlog( "No such field: $fieldid (found on index queue).. skipping.\n" );
			next;
		}
	
		EPrints::Index::indexlog( "* de-indexing: $fieldcode" ) if( $p->{loglevel} > 4 );
		EPrints::Index::remove( $session, $dataset, $objectid, $fieldid );
		EPrints::Index::indexlog( "* done-de-indexing: $fieldcode" ) if( $p->{loglevel} > 5 );
	
		next unless( $field->get_property( "text_index" ) );
	
		my $item = $dataset->get_object( $session, $objectid );
		next unless ( defined $item );
	
		my $value = $item->get_value( $fieldid );
		
		next unless EPrints::Utils::is_set( $value );	
	
		EPrints::Index::indexlog( "* indexing: $fieldcode" ) if( $p->{loglevel} > 4 );
		EPrints::Index::add( $session, $dataset, $objectid, $fieldid, $value );
		EPrints::Index::indexlog( "* done-indexing: $fieldcode" ) if( $p->{loglevel} > 5 );
	}

	return $seen_action;
}	

sub is_running
{
	my $pidfile = EPrints::Index::pidfile();
	return 0 if( !-e $pidfile );
	return 1;
}

sub suicidal
{
	return 1 if( -e EPrints::Index::suicidefile() );
	return 0;
}

sub stop
{
	# no params
	return -1 if( !EPrints::Index::is_running );

	my $suicidefile = EPrints::Index::suicidefile();
	open( SUICIDE, ">$suicidefile" );
	print SUICIDE <<END;
# This file is recreated by the indexer to indicate
# that the indexer should exit. 
END
	close SUICIDE;
	
	# give it 8 seconds
	my $counter = 8;
	for( 1..$counter )
	{
		if( !EPrints::Index::is_running )
		{
			return 1;
		}
		sleep 1;
	}
	
	# That didn't work - try to stop it using the command-line
	# approach.

	my $bin_path = EPrints::Index::binfile();
	system( "$bin_path", "stop" );
	# give it 10 seconds
	$counter = 10;
	for( 1..$counter )
	{
		if( !EPrints::Index::is_running )
		{
			return 1;
		}
		sleep 1;
	}
	return 0 if( EPrints::Index::is_running );
	return 1;
}

sub start
{
	my( $session ) = @_;

	return -1 if( EPrints::Index::is_running );

	EPrints::Index::_run_indexer( $session, "start" );	

	# give it 10 seconds
	my $counter = 10;
	for( 1..$counter )
	{
		if( EPrints::Index::is_running )
		{
			return 1;
		}
		sleep 1;
	}
	return 0 if( !EPrints::Index::is_running );
	return 1;
}

sub force_start
{
	my( $session ) = @_;

	EPrints::Index::stop( $session );

	unlink( EPrints::Index::pidfile() );
	unlink( EPrints::Index::tickfile() );

	return EPrints::Index::start( $session );
}

sub _run_indexer
{
	my( $session, $action ) = @_;
	my $bin_path = EPrints::Index::binfile();
	my $prog = <<END;
use strict;
use warnings;
use POSIX 'setsid';
chdir '/' or die "Can't chdir to /: \$!";
open STDIN, '/dev/null'  or die "Can't read /dev/null: \$!";
open STDOUT, '+>>', '/tmp/error_log' or die "Can't write to /dev/null: \$!";
open STDERR, '>&STDOUT'  or die "Can't dup stdout: \$!";
setsid or die "Can't start a new session: \$!";
\$ENV{EPRINTS_NO_CHECK_USER} = 1;
exec( "$bin_path", "$action" );
END
	$session->get_request->spawn_proc_prog( $EPrints::SystemSettings::conf->{executables}->{perl},
		["-e", $prog ] );

}


1;

######################################################################
=pod

=back

=cut

