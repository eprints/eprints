=head1 NAME

EPrints::Index::Daemon::MSWin32

=cut

package EPrints::Index::Daemon::MSWin32;

use Win32::Daemon;
use Win32::Process;
use Win32::Process qw( STILL_ACTIVE );
use Win32::Console;

use EPrints::Index::Daemon;
@ISA = qw( EPrints::Index::Daemon );
our $MASTER_SERVICE = 'EPrintsIndexer';
our $WORKER_SERVICE = 'EPrintsIndexerWorker';

use strict;

sub win32_error
{
	my( $self, $msg ) = @_;

	EPrints->abort( "$msg: $^E" );
}

sub is_worker_running
{
	my( $self ) = @_;

	return if !$self->{worker};

	$self->{worker}->GetExitCode( my $exitcode );
	return $exitcode == STILL_ACTIVE;
}

sub indexer_cmd
{
	my( $self, $cmd ) = @_;

	my $path = $EPrints::SystemSettings::conf->{base_path} . "/bin/indexer";
	my $params = '';

	$params .= " --loglevel=".$self->{loglevel};

	return "perl $path $params $cmd";
}

sub create_service
{
	my( $self ) = @_;

	my $rc = Win32::Daemon::CreateService({
		machine => '',
		name => $MASTER_SERVICE,
		display => 'EPrints Indexer',
		path => $EPrints::SystemSettings::conf->{executables}->{perl},
		user => '',
		pwd => '',
		description => 'EPrints Indexer master service',
		parameters => $self->indexer_cmd( "service" ),
	});
       
	if( !$rc )
	{
		$self->win32_error( 'Create EPrints Indexer service' );
	}

	return $rc;
}

sub delete_service
{
	my( $self ) = @_;

	my $rc = Win32::Daemon::DeleteService('', $MASTER_SERVICE);
	#Win32::Daemon::DeleteService('', $WORKER_SERVICE);

	if( !$rc )
	{
		$self->win32_error( 'Delete EPrints Indexer service' );
	}

	return $rc;
}

sub is_running
{
	my( $self ) = @_;

	my $status = {};
	if( !Win32::Service::GetStatus('',$MASTER_SERVICE,$status) )
	{
		$self->win32_error( "EPrints Indexer master state" );
	}

	return $status->{'CurrentState'} != SERVICE_STOPPED;
}

sub start
{
	shift->start_daemon( @_ );
}

sub start_daemon
{
	my( $self ) = @_;

	if( !Win32::Service::StartService('',$MASTER_SERVICE) )
	{
		$self->win32_error( "Starting EPrints Indexer service" );
	}

	return 1;
}

sub stop
{
	shift->stop_daemon( @_ );
}

sub stop_daemon
{
	my( $self ) = @_;

	if( !Win32::Service::StopService('',$MASTER_SERVICE) )
	{
		$self->win32_error( "Stopping EPrints Indexer service" );
	}

	return 1;
}

sub start_worker
{
	my( $self ) = @_;

	my $cmd = $self->indexer_cmd( "worker" );

	my $processObj;
	Win32::Process::Create($processObj,
		$^X,
		$cmd,
		0,
		NORMAL_PRIORITY_CLASS,
		"."
	) or $self->win32_error( $cmd );

	return $self->{worker} = $processObj;
}

sub stop_worker
{
	my( $self ) = @_;

	return if !$self->{worker};

	open(FH, ">", $self->{suicidefile})
		or EPrints->abort( "Error writing to $self->{suicidefile}: $!" );
	close(FH);

	# wait 30 seconds for the indexer to stop
	$self->{worker}->Wait( 30000 );
	if( $self->is_worker_running )
	{
		# terminate stops the indexer dead
		$self->log( 1, "** Worker failed to respond to INTERRUPT, terminating" );
		$self->{worker}->Kill( 0 );
	}

	delete $self->{worker};
	unlink($self->{suicidefile});
}

sub run_service
{
	my( $self ) = @_;

	$self->cleanup;

	if( $self->{logfile} )
	{
		open(STDOUT, ">>", $self->{logfile})
			or die "Error opening $self->{logfile}: $!";
		open(STDERR, ">>", $self->{logfile})
			or die "Error opening $self->{logfile}: $!";
	}

	$self->log( 1, "** Indexer process started" ); 
	$self->log( 3, "** Indexer control process started with process ID: $$" ); 

	$self->write_pid;

	# inlined all the functionality because this is a very thin control process
	Win32::Daemon::RegisterCallbacks( my $callbacks = {
		start => sub {
			my( $e, $context ) = @_;

			my $self = $context->{self};

			$self->start_worker;

			$context->{last_state} = SERVICE_RUNNING;
			Win32::Daemon::State( SERVICE_RUNNING );
		},
		running => sub {
			my( $e, $context ) = @_;

			my $self = $context->{self};

			return if SERVICE_RUNNING != Win32::Daemon::State();

			if( !$self->is_worker_running || $self->has_stalled )
			{
				if( $self->should_respawn )
				{
					$self->roll_logs;
				}
				$self->log( 2, "*** Starting indexer sub-process" );

				$self->start_worker;
			}
			Win32::Daemon::State($context->{last_state});
		},
		stop => sub {
			my( $e, $context ) = @_;

			$context->{self}->log( 1, "** Indexer process stopping" );

			$self->stop_worker;

			$context->{last_state} = SERVICE_STOPPED;
			Win32::Daemon::State( SERVICE_STOPPED );

			Win32::Daemon::StopService();
		},
		pause => sub {
			my( $e, $context ) = @_;

			$context->{last_state} = SERVICE_PAUSED;
			Win32::Daemon::State( SERVICE_PAUSED );
		},
		continue => sub {
			my( $e, $context ) = @_;

			$context->{last_state} = SERVICE_RUNNING;
			Win32::Daemon::State( SERVICE_RUNNING );
		},
	} );

	Win32::Console->Alloc
		or $self->win32_error;

	my %context = (
		last_state => SERVICE_STOPPED,
		start_time => time(),
		self => $self,
	);

	Win32::Daemon::StartService( \%context, 30000 );

	$self->cleanup;
}

sub cleanup
{
	my( $self ) = @_;

	unlink($self->{tickfile});
	unlink($self->{suicidefile});
	$self->remove_pid;
}

sub run_worker
{
	my( $self ) = @_;

	if( $self->{logfile} )
	{
		open(STDOUT, ">>", $self->{logfile})
			or die "Error opening $self->{logfile}: $!";
		open(STDERR, ">>", $self->{logfile})
			or die "Error opening $self->{logfile}: $!";
	}

	$self->log( 3, "** Worker process started: $$" );

	$self->run_index;

	unlink($self->{tickfile});
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

